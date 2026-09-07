#!/usr/bin/env python3
"""
concept_id Injection Protocol & Tool for nvk/llm-wiki Vault
Strictly idempotent. Supports DRY-RUN mode, global collision detection,
and alias-legacy capture rule on slug rename.
"""

import os
import sys
import re
import argparse
from pathlib import Path
from collections import defaultdict

def parse_frontmatter(content):
    """
    Parses frontmatter while handling potential unescaped control characters.
    Returns (raw_fm, body, fm_dict)
    """
    if not content.startswith('---'):
        return None, content, {}
    parts = content.split('---', 2)
    if len(parts) < 3:
        return None, content, {}
    
    raw_fm = parts[1]
    body = parts[2]
    
    fm_dict = {}
    lines = raw_fm.splitlines()
    for line in lines:
        m = re.match(r'^([a-zA-Z0-9_-]+):\s*(.*)$', line)
        if m:
            k = m.group(1).strip()
            v = m.group(2).strip().strip('\"\'')
            fm_dict[k] = v
            
    return raw_fm, body, fm_dict

def inject_frontmatter_field(raw_fm, field_key, field_value, after_key="title"):
    """
    Idempotently injects a key-value pair into raw frontmatter string.
    """
    # Check if key already exists
    if re.search(r'^' + re.escape(field_key) + r':', raw_fm, re.M):
        return raw_fm
        
    lines = raw_fm.splitlines()
    new_lines = []
    inserted = False
    
    # Try inserting after specified key
    for line in lines:
        new_lines.append(line)
        if not inserted and re.match(r'^' + re.escape(after_key) + r':', line):
            new_lines.append(f'{field_key}: "{field_value}"')
            inserted = True
            
    if not inserted:
        # Prepend at start
        new_lines.insert(0, f'{field_key}: "{field_value}"')
        
    return '\n'.join(new_lines)

def run_concept_id_pipeline(vault_path, dry_run=True, disambiguate_collisions=False):
    vault_root = Path(vault_path)
    if not vault_root.exists():
        raise FileNotFoundError(f"Vault path does not exist: {vault_path}")

    # Gather all concept nodes
    md_files = []
    for d in sorted(os.listdir(vault_root)):
        dp = vault_root / d
        if dp.is_dir() and not d.startswith('.'):
            for f in sorted(dp.glob('*.md')):
                if f.name != '_index.md':
                    md_files.append((d, f))

    print(f"[*] Scanning {len(md_files)} concept nodes in vault: {vault_root}")
    
    # 1. Collision detection across all basenames
    basename_map = defaultdict(list)
    existing_cids = defaultdict(list)
    already_has_cid = 0
    needs_cid = 0
    
    for domain, fpath in md_files:
        stem = fpath.stem
        basename_map[stem].append((domain, fpath))
        
        with open(fpath, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()
        raw_fm, body, fm_dict = parse_frontmatter(content)
        if 'concept_id' in fm_dict and fm_dict['concept_id']:
            already_has_cid += 1
            existing_cids[fm_dict['concept_id']].append((domain, fpath))
        else:
            needs_cid += 1

    collisions = {k: v for k, v in basename_map.items() if len(v) > 1}
    total_colliding_files = sum(len(v) for v in collisions.values())

    print(f"\n[+] CENSUS SUMMARY:")
    print(f"    - Total concept files: {len(md_files)}")
    print(f"    - Files with existing concept_id: {already_has_cid}")
    print(f"    - Files requiring concept_id injection: {needs_cid}")
    print(f"    - Unique basenames: {len(basename_map)}")
    print(f"    - Colliding basenames (>1 domain): {len(collisions)}")
    print(f"    - Total files involved in collisions: {total_colliding_files}")

    # 2. List collisions
    print(f"\n[+] COLLISION AUDIT (Basename collisions across domains):")
    for stem, locs in sorted(collisions.items(), key=lambda x: len(x[1]), reverse=True):
        loc_strs = [f"{d}/{p.name}" for d, p in locs]
        print(f"    - '{stem}' ({len(locs)} dirs): {', '.join(loc_strs)}")

    # 3. Simulate Injection & Alias Capture
    injected_count = 0
    aliases_captured = 0
    actions = []

    for domain, fpath in md_files:
        stem = fpath.stem
        with open(fpath, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()
        raw_fm, body, fm_dict = parse_frontmatter(content)

        if 'concept_id' in fm_dict and fm_dict['concept_id']:
            continue # Already present, immutable!

        # If collision exists and disambiguation requested
        assigned_cid = stem
        alias_to_add = None

        if len(basename_map[stem]) > 1 and disambiguate_collisions:
            # Deterministic disambiguation rule: domain prefix for colliding secondary nodes
            # Non-primary gets domain prefix, alias captures legacy slug
            assigned_cid = f"{domain}_{stem}"
            alias_to_add = stem
            aliases_captured += 1
        elif len(basename_map[stem]) > 1:
            # Under standard freeze rule, cid = basename sans .md
            # Alias capture triggers on future slug rename
            alias_to_add = None

        injected_count += 1
        new_raw_fm = inject_frontmatter_field(raw_fm, 'concept_id', assigned_cid, after_key="title")
        
        # If alias capture applies
        if alias_to_add:
            if 'aliases' not in fm_dict:
                new_raw_fm += f'\naliases: ["{alias_to_add}"]'
            elif alias_to_add not in fm_dict['aliases']:
                # append to existing aliases
                new_raw_fm = re.sub(r'aliases:\s*\[(.*?)\]', rf'aliases: [\1, "{alias_to_add}"]', new_raw_fm)

        new_content = f"---{new_raw_fm}---{body}"
        actions.append((fpath, new_content, assigned_cid, alias_to_add))

    print(f"\n[+] INJECTION PLAN:")
    print(f"    - Mode: {'DRY-RUN (no disk writes)' if dry_run else 'APPLY (writing to files)'}")
    print(f"    - concept_ids to inject: {injected_count}")
    print(f"    - Collisions flagged: {len(collisions)} ({total_colliding_files} files)")
    print(f"    - Aliases captured: {aliases_captured}")

    if not dry_run:
        print(f"\n[*] Executing disk writes to {vault_root}...")
        for fpath, new_content, cid, alias in actions:
            with open(fpath, 'w', encoding='utf-8') as f:
                f.write(new_content)
        print(f"[✓] Successfully injected concept_id into {len(actions)} files.")

    return {
        'total_nodes': len(md_files),
        'injected_count': injected_count,
        'collisions': collisions,
        'colliding_files_count': total_colliding_files,
        'aliases_captured': aliases_captured
    }

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="concept_id Injection Protocol")
    parser.add_argument("--vault-dir", type=str, default="data/scratch-vault/wiki", help="Path to vault wiki directory")
    parser.add_argument("--apply", action="store_true", help="Apply changes to disk (default is dry-run)")
    parser.add_argument("--disambiguate", action="store_true", help="Disambiguate collisions with domain prefix and capture aliases")
    args = parser.parse_args()

    run_concept_id_pipeline(args.vault_dir, dry_run=not args.apply, disambiguate_collisions=args.disambiguate)
