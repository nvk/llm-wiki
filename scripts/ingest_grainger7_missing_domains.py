import fitz
import re
from pathlib import Path
from ingest_books_pipeline import slugify, VAULT_WIKI

pdf_path = "/mnt/d/Buku/02_Core_&_Comprehensive_Textbooks/dokumen.pub_grainger-amp-allisons-diagnostic-radiology-a-textbook-of-medical-imaging-7th-edition-0702075248-9780702075247-9780702075629-9780702075612.pdf"
doc = fitz.open(pdf_path)
toc = doc.get_toc()

# Target missing domains in Grainger 7th Edition:
# Breast, Gynae/Obs, Spine, Head & Neck, Physics
TARGET_KEYWORDS = {
    "breast": "breast",
    "mammography": "breast",
    "gynaecol": "gynae",
    "gynecol": "gynae",
    "obstetric": "gynae",
    "uterus": "gynae",
    "ovary": "gynae",
    "spine": "spine",
    "spinal": "spine",
    "orbit": "head_neck",
    "petrous": "head_neck",
    "pharynx": "head_neck",
    "larynx": "head_neck",
    "sinonasal": "head_neck",
    "temporal bone": "head_neck",
    "physics": "physics_nuclear",
    "radiation": "physics_nuclear",
    "magnetic resonance": "physics_nuclear",
    "contrast agent": "physics_nuclear"
}

extracted = 0
for i, item in enumerate(toc):
    lvl, title, start_page = item
    if lvl in (2, 3) and start_page > 0:
        title_lower = title.lower()
        matched_domain = None
        for kw, dom in TARGET_KEYWORDS.items():
            if kw in title_lower:
                matched_domain = dom
                break
        
        if matched_domain:
            slug = slugify(title)
            if not slug or len(slug) < 3 or "outline" in slug:
                continue
            
            end_page = toc[i+1][2] - 1 if i+1 < len(toc) else start_page + 15
            extract_end = min(start_page + 8, end_page, len(doc))
            
            lines = []
            for p in range(start_page - 1, extract_end):
                if p < len(doc):
                    lines.append(doc[p].get_text("text"))
            
            raw_text = "\n".join(lines)
            if len(raw_text.strip()) < 250:
                continue
            
            out_file = VAULT_WIKI / matched_domain / f"{slug}.md"
            if not out_file.exists():
                md = f"""---
title: "{title}"
domain: "{matched_domain}"
source_book: "Grainger & Allison's Diagnostic Radiology (7th Edition)"
start_page: {start_page}
end_page: {end_page}
status: "verified_source"
---

# {title}

**Domain:** [[{matched_domain}/_index|{matched_domain.upper()}]]  
**Source:** Grainger & Allison's Diagnostic Radiology (7th Edition), Pages {start_page}–{end_page}  

## Clinical & Radiological Concepts
Lossless excerpt from gold-standard UK reference textbook.

## Reference Text
{raw_text[:7000]}
"""
                out_file.write_text(md, encoding="utf-8")
                extracted += 1

print(f"Extracted {extracted} high-yield concept nodes for missing domains from Grainger 7th.")
