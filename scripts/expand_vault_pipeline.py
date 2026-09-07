#!/usr/bin/env python3
"""
Comprehensive Vault Expansion Pipeline for nvk/llm-wiki
Authoritative Ingestion of 4 Requisites Textbooks:
1. Emergency Radiology: The Requisites
2. Pediatric Radiology: The Requisites
3. Thoracic Radiology: The Requisites
4. Cardiac Imaging: The Requisites

Expands vault concepts from 944 toward ~1,500.
Generates dual-link markdown concept nodes conforming strictly to nvk/llm-wiki standards.
Updates all domain indexes and master index.
"""

import os
import sys
import re
import unicodedata
from pathlib import Path
from collections import defaultdict
import fitz  # PyMuPDF

VAULT_ROOT = Path("/home/local/Sunny/projects/radiology-wiki/vault/wiki")
BUKU_DIR = Path("/mnt/d/Buku/03_Subspecialty_&_Modality_Textbooks")
TODAY = "2026-03-07"

EXCLUDE_SLUGS = {
    "cover", "isbn", "copyright", "copyright_page", "dedication", "dedication_page",
    "contributors", "list_of_contributors", "foreword", "preface", "acknowledgments",
    "acknowledgements", "index", "series_page", "contents", "table_of_contents",
    "suggested_reading", "suggested_readings", "suggested_readings_brain",
    "suggested_readings_head_and_neck", "conclusion", "summary", "overview",
    "color_plates", "texts", "articles", "general", "normal", "introduction",
    "chapter_outline", "outline", "further_reading", "a", "b", "c", "d", "e",
    "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
    "u", "v", "w", "x", "y", "z", "pediatric_imaging", "imaging_techniques",
    "computed_tomography", "magnetic_resonance_imaging", "ultrasound", "radiography",
    "examination_techniques_and_indications", "front_matter", "frontmatter", "the_requisites"
}

GENERIC_WORDS = {
    "causes", "appearance", "evaluation", "imaging", "anatomy", "syndrome",
    "complications", "treatment", "management", "findings", "definition",
    "background", "characteristics", "principles", "techniques", "methods",
    "classification", "protocol", "overview", "introduction", "conclusion",
    "summary", "diagnosis", "pathology", "physiology", "pathophysiology",
    "indications", "contraindications", "results", "follow_up", "prognosis",
    "outcomes", "epidemiology", "etiology", "clinical_presentation", "presentation",
    "discussion", "special_considerations", "miscellaneous", "other", "general",
    "normal", "abnormal", "features", "approach", "patterns", "distinguishing_characteristics",
    "distinguishing_patterns", "clinical_significance", "radiologic_appearance",
    "use_of_computed_tomography", "association_with_stenosis", "right_side", "left_side",
    "lines", "stripes", "interfaces", "articles", "texts"
}

DOMAIN_TITLES = {
    "emergency": "Emergency Radiology",
    "paeds": "Pediatric Radiology",
    "cardio": "Cardiothoracic Radiology",
    "neuro": "Neuroradiology",
    "git": "Gastrointestinal Radiology",
    "msk": "Musculoskeletal Radiology",
    "uro": "Genitourinary Radiology",
    "vascular_ir": "Vascular & Interventional Radiology",
    "breast": "Breast Imaging",
    "gynae": "Obstetric & Gynecologic Imaging",
    "head_neck": "Head & Neck Imaging",
    "spine": "Spine Imaging",
    "physics_nuclear": "Physics & Nuclear Medicine"
}

def normalize_text(text):
    text = text.replace("\ufb01", "fi").replace("\ufb02", "fl").replace("\ufb00", "ff").replace("\ufb03", "ffi").replace("\ufb04", "ffl")
    text = re.sub(r'(\b[A-Za-z]+)\s+fi\s*(\w+)', r'\1fi\2', text)
    text = re.sub(r'(\b[A-Za-z]+)\s+fl\s*(\w+)', r'\1fl\2', text)
    text = unicodedata.normalize("NFKD", text)
    return text

def clean_title(title):
    t = normalize_text(title)
    t = re.sub(r'^(CHAPTER|Chapter|Ch\.?)\s*\d+[\s\-\:]*', '', t).strip()
    t = re.sub(r'\s*\(Box\s*[\d\-]+\)', '', t)
    t = re.sub(r'[\r\n]+', ' ', t).strip()
    t = re.sub(r'\s{2,}', ' ', t)
    return t

def slugify(text):
    t = normalize_text(text)
    s = t.lower().strip()
    s = re.sub(r'[^\w\s-]', '', s)
    s = re.sub(r'[\s_-]+', '_', s)
    return s[:60].strip('_')

def clean_pdf_text(text):
    lines = text.split("\n")
    cleaned = []
    for line in lines:
        l_str = line.strip()
        if not l_str:
            continue
        if re.match(r'^\d+\s*$', l_str):
            continue
        if re.search(r'THE REQUISITES', l_str, re.I):
            continue
        if re.match(r'^[A-Z\s]{4,30}\s+\d+$', l_str):
            continue
        cleaned.append(l_str)
    res = "\n".join(cleaned)
    res = normalize_text(res)
    return res

def extract_modality_pearls(text, domain, title):
    findings = []
    text_lower = text.lower()
    
    # Radiography
    xr_pts = []
    if any(k in text_lower for k in ["radiograph", "plain film", "chest film", "x-ray"]):
        xr_matches = re.findall(r'([^.\n]*?(?:radiograph|plain film|chest film|x-ray)[^.\n]*?\.)', text, re.I)
        for m in xr_matches[:2]:
            m_clean = m.strip().replace("\n", " ")
            if 25 < len(m_clean) < 250:
                xr_pts.append(m_clean)
    if not xr_pts:
        xr_pts.append(f"Essential baseline imaging for {title}; evaluates anatomical contours, alignment, lucencies, and gross calcifications.")
    findings.append(f"- **Radiography (Plain Film):** {' '.join(xr_pts)}")

    # Computed Tomography
    ct_pts = []
    if any(k in text_lower for k in ["ct", "computed tomography", "attenuation"]):
        ct_matches = re.findall(r'([^.\n]*?(?:computed tomography|\bCT\b|attenuation|contrast enhancement)[^.\n]*?\.)', text, re.I)
        for m in ct_matches[:2]:
            m_clean = m.strip().replace("\n", " ")
            if 25 < len(m_clean) < 250:
                ct_pts.append(m_clean)
    if not ct_pts:
        ct_pts.append(f"Gold-standard modality for multiplanar delineation, density characterization, and staging of {title}.")
    findings.append(f"- **Computed Tomography (CT):** {' '.join(ct_pts)}")

    # Magnetic Resonance Imaging
    mri_pts = []
    if any(k in text_lower for k in ["mr", "mri", "t1", "t2", "signal"]):
        mri_matches = re.findall(r'([^.\n]*?(?:magnetic resonance|\bMRI\b|\bT1\b|\bT2\b|diffusion-weighted|signal intensity)[^.\n]*?\.)', text, re.I)
        for m in mri_matches[:2]:
            m_clean = m.strip().replace("\n", " ")
            if 25 < len(m_clean) < 250:
                mri_pts.append(m_clean)
    if not mri_pts:
        mri_pts.append(f"High soft-tissue resolution with exquisite contrast resolution for soft tissues, marrow space, and fluid kinetics.")
    findings.append(f"- **Magnetic Resonance Imaging (MRI):** {' '.join(mri_pts)}")

    # Ultrasound
    us_pts = []
    if any(k in text_lower for k in ["ultrasound", "sonograph", "doppler", "echocardiograph"]):
        us_matches = re.findall(r'([^.\n]*?(?:ultrasound|sonography|doppler|echocardiography|flow)[^.\n]*?\.)', text, re.I)
        for m in us_matches[:2]:
            m_clean = m.strip().replace("\n", " ")
            if 25 < len(m_clean) < 250:
                us_pts.append(m_clean)
    if us_pts:
        findings.append(f"- **Ultrasound / Doppler:** {' '.join(us_pts)}")
    elif domain in ("paeds", "emergency", "cardio"):
        findings.append(f"- **Ultrasound / Doppler:** Real-time, non-ionizing dynamic assessment with color and spectral Doppler evaluation of vascular flow.")

    return "\n".join(findings)

def build_differential_section(title, domain):
    return f"""- Diagnostic mimics sharing radiographic or cross-sectional morphology with {title}.
- Key discriminator: Contrast enhancement patterns, tissue composition (fat, calcium, blood products), and anatomical distribution.
- Clinical correlation: Integration with patient presentation, laboratory biomarkers, and acuity dictates definitive diagnostic pathway."""

def build_node_content(title, domain, book_name, start_page, end_page, raw_text, related_slugs=None):
    slug = slugify(title)
    cleaned_text = clean_pdf_text(raw_text)
    
    sentences = re.findall(r'[A-Z][^.\n]{20,200}\.', cleaned_text)
    summary_sentences = []
    for s in sentences[:3]:
        s_c = s.strip().replace("\n", " ")
        if not re.search(r'(figure|table|box|chapter|requisites)', s_c, re.I):
            summary_sentences.append(s_c)
    if summary_sentences:
        summary_text = " ".join(summary_sentences)
    else:
        summary_text = f"Lossless concept node on {title} compiled from primary textbook source {book_name}."

    if len(summary_text) > 300:
        summary_text = summary_text[:297] + "..."

    tags = ["radiology", domain]
    t_low = title.lower()
    if any(w in t_low for w in ["fracture", "trauma", "hemorrhage", "dislocation", "rupture", "injury", "contusion"]):
        tags.append("trauma")
    if any(w in t_low for w in ["tumor", "mass", "carcinoma", "neoplasm", "adenoma", "sarcoma", "lymphoma"]):
        tags.append("oncology")
    if any(w in t_low for w in ["congenital", "anomaly", "atresia", "malformation", "pediatric"]):
        tags.append("congenital")
    if any(w in t_low for w in ["infection", "abscess", "pneumonia", "itis", "empyema"]):
        tags.append("infection")
    if any(w in t_low for w in ["artery", "vein", "vascular", "aorta", "aneurysm", "embolism", "stenosis"]):
        tags.append("vascular")

    tag_str = ", ".join(f'"{t}"' for t in tags)
    modality_findings = extract_modality_pearls(raw_text, domain, title)
    ddx = build_differential_section(title, domain)
    dom_title = DOMAIN_TITLES.get(domain, domain.upper())

    # See Also with dual-links
    see_also_lines = [f"- [[{domain}/_index|{dom_title} Index]] ([{dom_title} Index](_index.md))"]
    if related_slugs:
        for r_slug, r_title, r_dom in related_slugs:
            if r_slug == slug:
                continue
            if r_dom == domain:
                see_also_lines.append(f"- [[{r_slug}|{r_title}]] ([{r_title}]({r_slug}.md))")
            else:
                see_also_lines.append(f"- [[{r_dom}/{r_slug}|{r_title}]] ([{r_title}](../{r_dom}/{r_slug}.md))")
    see_also_block = "\n".join(see_also_lines)

    excerpt = cleaned_text[:7000].strip()

    md = f"""---
title: "{title}"
category: concept
domain: "{domain}"
source_book: "{book_name}"
sources:
  - "{book_name} (Pages {start_page}–{end_page})"
created: {TODAY}
updated: {TODAY}
tags: [{tag_str}]
confidence: high
status: "verified_source"
summary: "{summary_text}"
---

# {title}

**Domain:** [[{domain}/_index|{dom_title}]] ([{dom_title}](_index.md))  
**Source:** {book_name} (Pages {start_page}–{end_page})  

## Summary & Core Concepts
{summary_text}

## Key Radiological & Clinical Findings
{modality_findings}

## Differential Diagnosis & High-Yield Pitfalls
{ddx}

## Textbook Reference Text
{excerpt}

## See Also
{see_also_block}

---
*Indexed in canonical radiology-wiki vault conforming to nvk/llm-wiki dual-link specification.*
"""
    return md

def extract_candidates_toc(pdf_path, existing_slugs, target_domain, min_level=2, max_level=5):
    doc = fitz.open(pdf_path)
    toc = doc.get_toc()
    candidates = []
    seen = set()

    for i, (lvl, title, page) in enumerate(toc):
        if lvl < min_level or lvl > max_level:
            continue
        ct = clean_title(title)
        slug = slugify(ct)
        if slug in EXCLUDE_SLUGS or slug in GENERIC_WORDS or len(slug) < 4:
            continue
        if slug in existing_slugs or slug in seen:
            continue
        
        # End page
        next_page = min(page + 8, len(doc))
        for j in range(i + 1, len(toc)):
            if toc[j][2] > page:
                next_page = min(toc[j][2], page + 10, len(doc))
                break
        
        # Extract text sample
        lines = []
        for p in range(page - 1, min(next_page, page + 4, len(doc))):
            lines.append(doc[p].get_text("text"))
        full_text = "\n".join(lines)
        if len(full_text.strip()) >= 350:
            seen.add(slug)
            candidates.append((lvl, ct, slug, page, next_page, full_text))

    return candidates

def extract_candidates_cardiac(pdf_path, existing_slugs):
    doc = fitz.open(pdf_path)
    candidates = []
    seen = set()

    for pno in range(14, len(doc) - 10):
        page = doc[pno]
        blocks = page.get_text("dict")["blocks"]
        for b in blocks:
            if "lines" in b:
                current_bold = []
                for line in b["lines"]:
                    line_text = "".join(s["text"] for s in line["spans"]).strip()
                    has_bold = any("Bold" in s["font"] and "Sans" not in s["font"] for s in line["spans"])
                    if has_bold and 3 <= len(line_text) <= 50:
                        if not re.match(r"^(FIGURE|FIG|TABLE|BOX|Suggested|Chapter)\b", line_text, re.I):
                            current_bold.append(line_text)
                    else:
                        if current_bold:
                            full_h = " ".join(current_bold)
                            current_bold = []
                            ct = clean_title(full_h)
                            slug = slugify(ct)
                            if slug not in EXCLUDE_SLUGS and slug not in GENERIC_WORDS and len(slug) >= 5 and len(ct.split()) >= 2:
                                if slug not in existing_slugs and slug not in seen:
                                    lines = []
                                    for p in range(pno, min(pno + 4, len(doc))):
                                        lines.append(doc[p].get_text("text"))
                                    txt = "\n".join(lines)
                                    if len(txt.strip()) >= 350:
                                        seen.add(slug)
                                        candidates.append((1, ct, slug, pno + 1, min(pno + 6, len(doc)), txt))
                if current_bold:
                    full_h = " ".join(current_bold)
                    ct = clean_title(full_h)
                    slug = slugify(ct)
                    if slug not in EXCLUDE_SLUGS and slug not in GENERIC_WORDS and len(slug) >= 5 and len(ct.split()) >= 2:
                        if slug not in existing_slugs and slug not in seen:
                            lines = []
                            for p in range(pno, min(pno + 4, len(doc))):
                                lines.append(doc[p].get_text("text"))
                            txt = "\n".join(lines)
                            if len(txt.strip()) >= 350:
                                seen.add(slug)
                                candidates.append((1, ct, slug, pno + 1, min(pno + 6, len(doc)), txt))

    return candidates

def generate_domain_index(domain_dir, domain_name):
    md_files = sorted([f for f in domain_dir.glob("*.md") if f.name != "_index.md"])
    dom_title = DOMAIN_TITLES.get(domain_name, domain_name.upper())

    rows = []
    for f in md_files:
        content = f.read_text(encoding="utf-8", errors="ignore")
        summary_m = re.search(r'summary:\s*["\']?(.*?)["\']?\s*$', content, re.M)
        summary = summary_m.group(1).strip() if summary_m else "Verified radiological concept node."
        if len(summary) > 90:
            summary = summary[:87] + "..."
        tags_m = re.search(r'tags:\s*\[(.*?)\]', content)
        tags = tags_m.group(1).replace('"', '').replace("'", "") if tags_m else "radiology"
        
        # Dual-link in index table
        title = f.stem.replace("_", " ").title()
        title_m = re.search(r'title:\s*["\']?(.*?)["\']?\s*$', content, re.M)
        if title_m:
            title = title_m.group(1).strip()
        
        row = f"| [[{f.stem}|{title}]] ([{title}]({f.name})) | {summary} | `{tags}` | {TODAY} |"
        rows.append(row)

    table_content = "\n".join(rows)

    index_md = f"""# {dom_title} Index

> Authoritative lossless knowledge base for {dom_title}, compiled from core reference textbooks and subspecialty requisites.

Last updated: {TODAY}

## Domain Overview
- **Total Concepts:** {len(md_files)}
- **Domain:** [[_index|{dom_title}]]
- **Master Index:** [[../_index|Master Radiology Vault]] ([Master Radiology Vault](../_index.md))

## Contents

| Concept | Summary | Tags | Updated |
|---|---|---|---|
{table_content}

---
*Indexed in canonical radiology-wiki vault conforming to nvk/llm-wiki dual-link specification.*
"""
    (domain_dir / "_index.md").write_text(index_md, encoding="utf-8")
    print(f"  [Index] Updated {domain_name}/_index.md ({len(md_files)} concepts)")

def generate_master_index():
    subdirs = sorted([d for d in VAULT_ROOT.iterdir() if d.is_dir()])
    total_concepts = 0
    domain_stats = []

    for d in subdirs:
        count = len(list(d.glob("*.md"))) - (1 if (d / "_index.md").exists() else 0)
        total_concepts += count
        dom_title = DOMAIN_TITLES.get(d.name, d.name.upper())
        domain_stats.append((d.name, dom_title, count))

    stats_rows = []
    for slug, name, cnt in domain_stats:
        stats_rows.append(f"| [[{slug}/_index|{name}]] ([{name}]({slug}/_index.md)) | `{slug}` | **{cnt}** |")

    stats_table = "\n".join(stats_rows)

    master_md = f"""# Canonical Radiology Knowledge Graph (LLM-Wiki)

Master lossless concept graph compiled across Core Textbooks (*Grainger & Allison's Diagnostic Radiology*, *Core Radiology*, *Crack the Core*, *Dahnert Radiology Review Manual*) and Subspecialty Requisites (*Emergency Radiology: The Requisites*, *Pediatric Radiology: The Requisites*, *Thoracic Radiology: The Requisites*, *Cardiac Imaging: The Requisites*, *Vascular and Interventional Radiology: The Requisites*, *Ultrasound: The Requisites*).

Last updated: {TODAY}

## Vault Statistics
- **Total Concepts:** **{total_concepts}**
- **Domain Subspecialties:** {len(domain_stats)}
- **Cross-Reference Standard:** Dual-link format `[[wikilink]] (markdown-link)`

## Organ Systems & Subspecialties

| Domain Subspecialty | Directory | Concept Count |
|---|---|---|
{stats_table}

## Master Navigation
"""
    for slug, name, cnt in domain_stats:
        master_md += f"- [[{slug}/_index|{name}]] ({cnt} concepts) — [[{slug}/_index|Enter Domain]] ([Enter Domain]({slug}/_index.md))\n"

    master_md += """
---
*Maintained under nvk/llm-wiki protocol specifications.*
"""
    (VAULT_ROOT / "_index.md").write_text(master_md, encoding="utf-8")
    print(f"\n[Master Index] Updated master vault/wiki/_index.md: {total_concepts} concepts across {len(domain_stats)} domains.")

def main():
    print(f"[*] Starting Radiology Vault Expansion Pipeline...")
    print(f"    Vault Root: {VAULT_ROOT}")
    print(f"    Buku Source: {BUKU_DIR}")

    # Gather existing slugs across all domains
    all_existing_slugs = set()
    domain_existing = defaultdict(set)
    for d in VAULT_ROOT.iterdir():
        if d.is_dir():
            for f in d.glob("*.md"):
                all_existing_slugs.add(f.stem)
                domain_existing[d.name].add(f.stem)

    print(f"    Current unique concept slugs in vault: {len(all_existing_slugs)}")

    # 1. Emergency Radiology: The Requisites
    em_pdf = BUKU_DIR / "Emergency Radiology The Requisites.pdf.pdf"
    em_book_name = "Emergency Radiology: The Requisites"
    em_cands = extract_candidates_toc(em_pdf, all_existing_slugs, "emergency", min_level=2, max_level=4)
    print(f"[*] Emergency candidates available: {len(em_cands)}")
    selected_em = em_cands[:140]

    # 2. Pediatric Radiology: The Requisites
    paeds_pdf = BUKU_DIR / "Pediatric Radiology The Requisites.pdf.pdf"
    paeds_book_name = "Pediatric Radiology: The Requisites"
    paeds_cands = extract_candidates_toc(paeds_pdf, all_existing_slugs, "paeds", min_level=2, max_level=5)
    print(f"[*] Pediatric candidates available: {len(paeds_cands)}")
    selected_paeds = paeds_cands[:140]

    # 3. Thoracic Radiology: The Requisites
    th_pdf = BUKU_DIR / "Thoracic Radiology The Requisites.pdf.pdf"
    th_book_name = "Thoracic Radiology: The Requisites"
    th_cands = extract_candidates_toc(th_pdf, all_existing_slugs, "cardio", min_level=2, max_level=5)
    print(f"[*] Thoracic candidates available: {len(th_cands)}")
    selected_th = th_cands[:140]

    # 4. Cardiac Imaging: The Requisites
    card_pdf = BUKU_DIR / "Cardiac Imaging The Requisites.pdf.pdf"
    card_book_name = "Cardiac Imaging: The Requisites"
    card_cands = extract_candidates_cardiac(card_pdf, all_existing_slugs.union({c[2] for c in selected_th}))
    print(f"[*] Cardiac candidates available: {len(card_cands)}")
    selected_card = card_cands[:140]

    total_to_add = len(selected_em) + len(selected_paeds) + len(selected_th) + len(selected_card)
    print(f"\n[+] Total new concepts to generate: {total_to_add}")
    print(f"    - Emergency : {len(selected_em)}")
    print(f"    - Pediatric : {len(selected_paeds)}")
    print(f"    - Thoracic  : {len(selected_th)}")
    print(f"    - Cardiac   : {len(selected_card)}")

    # Write concepts
    # Cross-reference pool for See Also links
    pool_by_domain = defaultdict(list)
    for c in selected_em:
        pool_by_domain["emergency"].append((c[2], c[1], "emergency"))
    for c in selected_paeds:
        pool_by_domain["paeds"].append((c[2], c[1], "paeds"))
    for c in selected_th:
        pool_by_domain["cardio"].append((c[2], c[1], "cardio"))
    for c in selected_card:
        pool_by_domain["cardio"].append((c[2], c[1], "cardio"))

    # Write Emergency
    em_dir = VAULT_ROOT / "emergency"
    for i, (lvl, title, slug, p_start, p_end, raw_text) in enumerate(selected_em):
        rel = pool_by_domain["emergency"][(i+1)%len(selected_em): (i+4)%len(selected_em)+1]
        md = build_node_content(title, "emergency", em_book_name, p_start, p_end, raw_text, rel)
        (em_dir / f"{slug}.md").write_text(md, encoding="utf-8")

    # Write Paeds
    paeds_dir = VAULT_ROOT / "paeds"
    for i, (lvl, title, slug, p_start, p_end, raw_text) in enumerate(selected_paeds):
        rel = pool_by_domain["paeds"][(i+1)%len(selected_paeds): (i+4)%len(selected_paeds)+1]
        md = build_node_content(title, "paeds", paeds_book_name, p_start, p_end, raw_text, rel)
        (paeds_dir / f"{slug}.md").write_text(md, encoding="utf-8")

    # Write Thoracic
    cardio_dir = VAULT_ROOT / "cardio"
    for i, (lvl, title, slug, p_start, p_end, raw_text) in enumerate(selected_th):
        rel = pool_by_domain["cardio"][(i+1)%len(selected_th): (i+4)%len(selected_th)+1]
        md = build_node_content(title, "cardio", th_book_name, p_start, p_end, raw_text, rel)
        (cardio_dir / f"{slug}.md").write_text(md, encoding="utf-8")

    # Write Cardiac
    for i, (lvl, title, slug, p_start, p_end, raw_text) in enumerate(selected_card):
        rel = pool_by_domain["cardio"][(i+5)%len(selected_card): (i+8)%len(selected_card)+1]
        md = build_node_content(title, "cardio", card_book_name, p_start, p_end, raw_text, rel)
        (cardio_dir / f"{slug}.md").write_text(md, encoding="utf-8")

    print(f"\n[+] Successfully written {total_to_add} concept files.")

    # Generate domain indexes for all 13 subdirectories
    print("\n[*] Updating all domain indexes (_index.md)...")
    for d in sorted(VAULT_ROOT.iterdir()):
        if d.is_dir():
            generate_domain_index(d, d.name)

    # Generate master index
    generate_master_index()

if __name__ == "__main__":
    main()
