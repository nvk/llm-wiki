#!/usr/bin/env python3
"""
Forensic Audit & Classification Tool for Vault v2
Reads vault/wiki (pure read-only) or data/scratch-vault/
Computes census, re-homing map, collision detection, deep-links, and index specs.
"""

import os
import sys
import re
import yaml
from pathlib import Path
from collections import defaultdict, Counter

VAULT_DIR = Path("vault/wiki")
DOMAINS = [
    "breast", "cardio", "emergency", "git", "gynae", "head_neck",
    "msk", "neuro", "paeds", "physics_nuclear", "spine", "uro", "vascular_ir"
]

def clean_text_for_evidence(text, max_words=80):
    # Strip markdown links, wikilinks, bold, italics, headers
    t = re.sub(r'\[\[([^\]\|]+)(?:\|([^\]]+))?\]\]', r'\2', text)
    t = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', t)
    t = re.sub(r'[*_`#>-]', ' ', t)
    t = re.sub(r'\s+', ' ', t).strip()
    words = t.split()
    if len(words) > max_words:
        return ' '.join(words[:max_words]) + '...'
    return ' '.join(words)

def extract_node_data(filepath):
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    
    parts = content.split('---', 2)
    fm_raw = parts[1] if len(parts) >= 3 else ''
    body_raw = parts[2] if len(parts) >= 3 else content
    
    # Title extraction
    title = None
    m_title = re.search(r'^title:\s*["\']?(.*?)["\']?\s*$', fm_raw, re.M)
    if m_title:
        title = m_title.group(1).strip()
    else:
        m_h1 = re.search(r'^#\s+(.+)$', body_raw, re.M)
        if m_h1:
            title = m_h1.group(1).strip()
        else:
            title = filepath.stem
            
    # Domain extraction
    domain = None
    m_dom = re.search(r'^domain:\s*["\']?(.*?)["\']?\s*$', fm_raw, re.M)
    if m_dom:
        domain = m_dom.group(1).strip()
    else:
        domain = filepath.parent.name
        
    # Sources extraction
    has_source = False
    source_val = None
    m_sb = re.search(r'^source_book:\s*["\']?(.*?)["\']?\s*$', fm_raw, re.M)
    m_src = re.search(r'^source:\s*["\']?(.*?)["\']?\s*$', fm_raw, re.M)
    m_srcs = re.search(r'^sources:\s*$', fm_raw, re.M)
    if m_sb:
        has_source = True
        source_val = m_sb.group(1).strip()
    elif m_src:
        has_source = True
        source_val = m_src.group(1).strip()
    elif m_srcs:
        has_source = True
        source_val = "sources list"
        
    has_concept_id = bool(re.search(r'^concept_id:\s*', fm_raw, re.M))
    has_aliases = bool(re.search(r'^aliases:\s*', fm_raw, re.M))
    
    # Opening sentence from body
    lines = body_raw.strip().splitlines()
    opening = ""
    for line in lines:
        l = line.strip()
        if not l or l.startswith('#') or l.startswith('**Domain:') or l.startswith('**Source:') or l.startswith('**System:') or l.startswith('**Multi-Book Sources:'):
            continue
        # Take first substantive sentence
        cleaned = clean_text_for_evidence(l, max_words=60)
        if len(cleaned.split()) >= 3:
            opening = cleaned
            break
    if not opening:
        opening = "Verified textbook concept node."
        
    words = len(body_raw.split())
    has_urls = bool(re.search(r'https?://', body_raw) or re.search(r'https?://', fm_raw))
    
    return {
        'filepath': filepath,
        'filename': filepath.name,
        'stem': filepath.stem,
        'domain': domain,
        'title': title,
        'opening': opening,
        'has_concept_id': has_concept_id,
        'has_aliases': has_aliases,
        'has_source': has_source,
        'source_val': source_val,
        'words': words,
        'has_urls': has_urls,
        'content': content
    }

if __name__ == "__main__":
    print("Testing extract_node_data...")
    node = extract_node_data(VAULT_DIR / "cardio" / "tetralogy_of_fallot.md")
    print("Extracted title:", node['title'])
    print("Opening:", node['opening'])
