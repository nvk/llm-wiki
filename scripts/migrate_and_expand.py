import shutil
import re
from pathlib import Path

OLD_WIKI = Path("/home/local/Sunny/projects/MMed-Radio-SBA/data/wiki_index")
NEW_VAULT = Path("/home/local/Sunny/projects/radiology-wiki/vault/wiki")

# System folder mapping
SYS_MAP = {
    "cardio": "cardio",
    "git": "git",
    "msk": "msk",
    "neuro": "neuro",
    "uro": "uro"
}

migrated = 0
for old_sys, new_sys in SYS_MAP.items():
    old_dir = OLD_WIKI / old_sys
    if not old_dir.exists():
        continue
    target_dir = NEW_VAULT / new_sys
    target_dir.mkdir(parents=True, exist_ok=True)
    
    for f in old_dir.glob("*.md"):
        title = f.stem.replace("_", " ").title()
        content = f.read_text(encoding="utf-8", errors="ignore")
        
        # Ensure YAML frontmatter exists
        if not content.startswith("---"):
            header = f"""---
title: "{title}"
domain: "{new_sys}"
source: "Grainger & Allison / Core / Crack the Core (Lossless Concept Index)"
status: "verified_source"
---

"""
            content = header + content
        
        target_file = target_dir / f.name
        if not target_file.exists():
            target_file.write_text(content, encoding="utf-8")
            migrated += 1
        else:
            # Append if already exists from Requisites
            with open(target_file, "a", encoding="utf-8") as tf:
                tf.write(f"\n\n## Multi-Book Evidence (Grainger & Allison / Core / Crack the Core)\n\n" + content[:4000])
            migrated += 1

print(f"Migrated & merged {migrated} foundational concept nodes from old wiki.")

print("\n--- Canonical nvk/llm-wiki Vault Current Counts ---")
total = 0
for sub in sorted(NEW_VAULT.iterdir()):
    if sub.is_dir():
        c = len(list(sub.glob("*.md")))
        total += c
        print(f"  {sub.name:16}: {c:4d} nodes")
print(f"Total concept nodes in vault: {total}")
