#!/usr/bin/env python3
"""
PDF Text Extraction Script
Extracts text from PDF files and saves to text files for review.
"""

import sys
import os
from pathlib import Path

try:
    import PyPDF2
except ImportError:
    print("ERROR: PyPDF2 not installed.")
    print("Please install it using: pip install PyPDF2")
    print("Or install all requirements: pip install -r requirements.txt")
    sys.exit(1)

try:
    import pdfplumber
except ImportError:
    print("WARNING: pdfplumber not installed. Will use PyPDF2 only.")
    print("For better extraction, install: pip install pdfplumber")
    pdfplumber = None


def extract_with_pypdf2(pdf_path):
    """Extract text using PyPDF2 (fallback method)."""
    text = ""
    try:
        with open(pdf_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            for page_num, page in enumerate(pdf_reader.pages):
                text += f"\n--- Page {page_num + 1} ---\n"
                text += page.extract_text()
    except Exception as e:
        print(f"Error with PyPDF2: {e}")
    return text


def extract_with_pdfplumber(pdf_path):
    """Extract text using pdfplumber (better method)."""
    if pdfplumber is None:
        return None
    text = ""
    try:
        with pdfplumber.open(pdf_path) as pdf:
            for page_num, page in enumerate(pdf.pages):
                text += f"\n{'='*80}\n"
                text += f"Page {page_num + 1}\n"
                text += f"{'='*80}\n\n"
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
    except Exception as e:
        print(f"Error with pdfplumber: {e}")
        return None
    return text


def extract_pdf(pdf_path, output_path=None):
    """Extract text from PDF file."""
    pdf_path = Path(pdf_path)
    
    if not pdf_path.exists():
        print(f"Error: PDF file not found: {pdf_path}")
        return False
    
    print(f"Extracting text from: {pdf_path.name}")
    
    # Try pdfplumber first (better quality)
    text = extract_with_pdfplumber(pdf_path)
    
    # Fallback to PyPDF2 if pdfplumber fails
    if not text or len(text.strip()) < 100:
        print("pdfplumber extraction failed or insufficient text, trying PyPDF2...")
        text = extract_with_pypdf2(pdf_path)
    
    if not text or len(text.strip()) < 50:
        print("Warning: Very little text extracted. PDF might be image-based or encrypted.")
        return False
    
    # Determine output path
    if output_path is None:
        output_path = pdf_path.parent / f"{pdf_path.stem}_extracted.txt"
    else:
        output_path = Path(output_path)
    
    # Write extracted text
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(f"Extracted from: {pdf_path.name}\n")
        f.write(f"{'='*80}\n\n")
        f.write(text)
    
    print(f"Text extracted to: {output_path}")
    print(f"Extracted {len(text)} characters")
    return True


def main():
    """Main function."""
    # Default PDF paths
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    spec_dir = project_root / "Spec"
    
    pdf_files = [
        spec_dir / "Configurable-Packet-Modifier-CPM-Design-Specification-Version-1.0.pdf",
        spec_dir / "CPM-Final-Project-Verification-Requirements-and-Deliverables.pdf"
    ]
    
    if len(sys.argv) > 1:
        # Use command line arguments
        pdf_files = [Path(arg) for arg in sys.argv[1:]]
    
    # Extract from all PDFs
    for pdf_file in pdf_files:
        if pdf_file.exists():
            extract_pdf(pdf_file)
        else:
            print(f"Warning: PDF not found: {pdf_file}")
    
    print("\nExtraction complete!")


if __name__ == "__main__":
    main()
