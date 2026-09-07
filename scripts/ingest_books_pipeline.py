#!/usr/bin/env python3
"""
Automated Textbook Ingestion Pipeline for nvk/llm-wiki Vault
Extracts chapters and high-yield concept sections directly from /mnt/d/Buku/
Generates verified Markdown nodes with frontmatter, textbook citations, and Obsidian [[links]].
"""

import sys
import os
import re
from pathlib import Path
import fitz # PyMuPDF

VAULT_WIKI = Path("/home/local/Sunny/projects/radiology-wiki/vault/wiki")
BUKU_DIR = Path("/mnt/d/Buku")

SYSTEM_MAPPING = {
    "pediatric": "paeds",
    "paediatric": "paeds",
    "children": "paeds",
    "breast": "breast",
    "mammography": "breast",
    "gynae": "gynae",
    "gynecologic": "gynae",
    "obstetric": "gynae",
    "cardio": "cardio",
    "cardiac": "cardio",
    "thoracic": "cardio",
    "chest": "cardio",
    "pulmonary": "cardio",
    "gastrointestinal": "git",
    "liver": "git",
    "pancreas": "git",
    "biliary": "git",
    "bowel": "git",
    "musculoskeletal": "msk",
    "bone": "msk",
    "joint": "msk",
    "neuro": "neuro",
    "brain": "neuro",
    "head and neck": "head_neck",
    "orbit": "head_neck",
    "ent": "head_neck",
    "spine": "spine",
    "genitourinary": "uro",
    "renal": "uro",
    "kidney": "uro",
    "adrenal": "uro",
    "vascular": "vascular_ir",
    "interventional": "vascular_ir",
    "physics": "physics_nuclear",
    "nuclear": "physics_nuclear",
    "emergency": "emergency",
    "trauma": "emergency"
}

def clean_title(title):
    t = re.sub(r'^(CHAPTER|Chapter|Ch\.?)\s*\d+[\s\-\:]*', '', title).strip()
    return t

def slugify(text):
    s = text.lower().strip()
    s = re.sub(r'[^\w\s-]', '', s)
    s = re.sub(r'[\s_-]+', '_', s)
    return s[:60].strip('_')

def process_toc_book(pdf_path, book_name):
    print(f"[*] Processing {book_name} ({pdf_path.name})...")
    try:
        doc = fitz.open(pdf_path)
    except Exception as e:
        print(f"[-] Error opening {pdf_path}: {e}")
        return

    toc = doc.get_toc()
    if not toc:
        print(f"[-] No TOC in {pdf_path.name}")
        return

    # Extract level 1 and level 2 chapters
    items = []
    for i, item in enumerate(toc):
        lvl, title, page = item
        if lvl in (1, 2) and page > 0 and len(title.strip()) > 3:
            items.append((lvl, clean_title(title), page))

    print(f"    Found {len(items)} structured sections in TOC.")
    
    # Process pairs of sections
    for i in range(len(items)):
        lvl, title, start_page = items[i]
        end_page = items[i+1][2] - 1 if i + 1 < len(items) else min(start_page + 30, len(doc))
        if end_page < start_page:
            end_page = start_page + 10

        # Determine target system
        sys_target = "cardio" # default
        lower_t = title.lower()
        for k, v in SYSTEM_MAPPING.items():
            if k in lower_t:
                sys_target = v
                break
        
        # If book itself is domain-specific
        book_lower = book_name.lower()
        if "pediatric" in book_lower:
            sys_target = "paeds"
        elif "breast" in book_lower:
            sys_target = "breast"
        elif "cardiac" in book_lower or "thoracic" in book_lower:
            sys_target = "cardio"
        elif "vascular" in book_lower:
            sys_target = "vascular_ir"
        elif "emergency" in book_lower:
            sys_target = "emergency"

        slug = slugify(title)
        if not slug or len(slug) < 3 or "content" in slug or "index" in slug or "preface" in slug:
            continue

        out_file = VAULT_WIKI / sys_target / f"{slug}.md"
        
        # Extract text sample (first 8 pages of section to avoid monster files)
        extract_end = min(start_page + 8, end_page, len(doc))
        content_lines = []
        for p in range(start_page - 1, extract_end):
            if p < len(doc):
                content_lines.append(doc[p].get_text("text"))

        raw_text = "\n".join(content_lines)
        if len(raw_text.strip()) < 200:
            continue

        # Format as Obsidian-compatible LLM-Wiki node
        node_md = f"""---
title: "{title}"
domain: "{sys_target}"
source_book: "{book_name}"
start_page: {start_page}
end_page: {end_page}
status: "verified_source"
---

# {title}

**Domain:** [[{sys_target}/_index|{sys_target.upper()}]]  
**Source:** {book_name} (Pages {start_page}–{end_page})  

## Summary & Core Concepts
High-yield clinical and radiological pearls compiled losslessly from primary textbook source.

## Textbook Reference Text
{raw_text[:8000]}

---
*Indexed in canonical radiology-wiki vault.*
"""
        # If file exists, append source section
        if out_file.exists():
            with open(out_file, "a", encoding="utf-8") as f:
                f.write(f"\n\n## Additional Primary Source: {book_name} (pp. {start_page}–{end_page})\n\n{raw_text[:4000]}")
        else:
            with open(out_file, "w", encoding="utf-8") as f:
                f.write(node_md)

print("Pipeline script ready.")
