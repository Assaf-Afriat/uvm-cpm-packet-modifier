# PDF Text Extraction Script

## Purpose
Extracts text from PDF specification files for review and analysis.

## Installation

```bash
pip install -r requirements.txt
```

Or install individually:
```bash
pip install PyPDF2 pdfplumber
```

## Usage

### Extract from default PDFs (in Spec folder):
```bash
python extract_pdf_text.py
```

### Extract from specific PDF file:
```bash
python extract_pdf_text.py path/to/file.pdf
```

### Extract from multiple PDFs:
```bash
python extract_pdf_text.py file1.pdf file2.pdf
```

## Output
The script creates `*_extracted.txt` files in the same directory as the PDFs, containing the extracted text.

## Notes
- Uses `pdfplumber` first (better quality)
- Falls back to `PyPDF2` if needed
- Handles multi-page PDFs
- Preserves page boundaries in output
