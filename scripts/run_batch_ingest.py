import os
import sys
from pathlib import Path
from ingest_books_pipeline import process_toc_book, BUKU_DIR

BOOKS_TO_PROCESS = [
    (BUKU_DIR / "03_Subspecialty_&_Modality_Textbooks/Pediatric Radiology The Requisites.pdf.pdf", "Pediatric Radiology: The Requisites"),
    (BUKU_DIR / "03_Subspecialty_&_Modality_Textbooks/Cardiac Imaging The Requisites.pdf.pdf", "Cardiac Imaging: The Requisites"),
    (BUKU_DIR / "03_Subspecialty_&_Modality_Textbooks/Thoracic Radiology The Requisites.pdf.pdf", "Thoracic Radiology: The Requisites"),
    (BUKU_DIR / "03_Subspecialty_&_Modality_Textbooks/Emergency Radiology The Requisites.pdf.pdf", "Emergency Radiology: The Requisites"),
    (BUKU_DIR / "03_Subspecialty_&_Modality_Textbooks/dokumen.pub_the-requisites-vascular-and-interventional-radiology-2nbsped-9780323045841-0323045847.pdf", "Vascular and Interventional Radiology: The Requisites"),
    (BUKU_DIR / "03_Subspecialty_&_Modality_Textbooks/Ultrasound the requisites.pdf.pdf", "Ultrasound: The Requisites"),
    (BUKU_DIR / "03_Subspecialty_&_Modality_Textbooks/clinical mr imaging and physics.pdf", "Clinical MR Imaging and Physics"),
    (BUKU_DIR / "02_Core_&_Comprehensive_Textbooks/Radiology Review Manual 8th ed (2017).pdf", "Dahnert Radiology Review Manual (8th Ed)"),
    (BUKU_DIR / "02_Core_&_Comprehensive_Textbooks/core-radiology-no-watermark-pdf-free.pdf", "Core Radiology (Jacob)"),
]

for pdf_path, book_name in BOOKS_TO_PROCESS:
    if pdf_path.exists():
        process_toc_book(pdf_path, book_name)
    else:
        print(f"Skipping missing: {pdf_path}")

print("\n--- Ingestion complete! Summary of generated nodes: ---")
vault_wiki = Path("/home/local/Sunny/projects/radiology-wiki/vault/wiki")
for sub in sorted(vault_wiki.iterdir()):
    if sub.is_dir():
        count = len(list(sub.glob("*.md")))
        print(f"  {sub.name:16}: {count} nodes")
