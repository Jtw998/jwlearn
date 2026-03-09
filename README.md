# JWLearn - Intelligent Medical Postgraduate Entrance Exam Learning Assistant

JWLearn is an open-source intelligent learning tool designed for medical postgraduate entrance examination preparation (specifically for China's Western Medicine Comprehensive Exam). It provides automatic PDF textbook parsing, question bank management, intelligent exam generation, spaced repetition review for wrong questions, and automatic knowledge point association.

## ✨ Core Features

### 📚 Intelligent Textbook Parsing
- Automatic OCR recognition for PDF textbooks/lecture notes
- Auto-structured knowledge point extraction and chapter hierarchy construction
- Full-text knowledge point search and intelligent Q&A
- Automatic association between knowledge points and corresponding question bank questions

### 📝 Question Bank Management System
- Automatic PDF question bank import with intelligent recognition of questions, options, answers, and explanations
- Multi-dimensional question extraction by chapter, question type, and difficulty level
- Intelligent exam generation with customizable difficulty distribution, question type score ratio, and knowledge point coverage
- Export exam papers to Markdown format ready for printing

### 🧠 Smart Review System
- Automatic wrong question recording with FSRS (Free Spaced Repetition System) algorithm for optimized review scheduling
- Automatic weak knowledge point identification and targeted practice question generation
- Filter wrong questions by chapter or difficulty for focused review

### 🎯 Automatic Exercise Generation
- Automatically generate various question types (multiple choice, true/false, fill-in-the-blank) based on knowledge points
- Question style matches Western Medicine Comprehensive Exam patterns with answers and detailed explanations
- Support question generation by chapter or specific knowledge point range

## 🛠️ Installation Dependencies

### System Dependencies
- bash 4.0+
- Python 3.9+
- jq 1.6+
- qpdf (for PDF manipulation)

### Python Dependencies
```bash
pip install PyMuPDF requests tqdm scikit-learn pandas numpy pybedtools pysam
```

### API Configuration
You need to apply for a Doubao (ByteDance) API key. Replace `YOUR_DOUBAO_API_KEY` with your own API key in `scripts/utils.sh` and `scripts/ocr_extract.py`.

## 🚀 Quick Start

### 1. Import Textbook
```bash
/learn parse --input "internal_medicine_textbook.pdf" --auto-add true
```
Automatically parse PDF textbook and structure knowledge points.

### 2. Import Question Bank
```bash
/learn bank-import "practice_questions.pdf" "Internal Medicine" "2025 Medical Exam Practice Questions"
```
Automatically recognize questions, answers, and explanations from PDF question bank.

### 3. Practice with Extracted Questions
```bash
# Extract 20 single-choice questions from Chapter 1
/learn bank-extract bank_xxx 20 --chapter chapter_01 --type single_choice
```

### 4. Generate Mock Exam
```bash
# Generate 100-point / 90-minute mock exam
/learn exam-generate bank_xxx "Mock Exam 1" 100 90 "3:5:2" "single_choice:2,multiple_choice:3" 0.8 "mock.md"
```

### 5. Review Wrong Questions
```bash
# Review due questions for today
/learn wrongbook review
```

### 6. Generate Practice Exercises
```bash
# Generate 15 mixed questions for Chapter 2
/learn generate --source "Internal Medicine Textbook" --count 15 --type all --chapter "Bronchial Asthma"
```

## 📂 Project Structure
```
jwlearn/
├── data/                  # Data storage directory
│   ├── knowledge/        # Structured knowledge point storage
│   ├── indexes/          # Search indexes
│   ├── schema.json       # Data structure definition
│   ├── question_banks.json # Question bank data
│   ├── wrong_questions.json # Wrong question book
│   └── exam_papers.json   # Generated exam papers
├── scripts/               # Core scripts
│   ├── bank_import.sh     # Question bank import
│   ├── bank_list.sh       # Question bank browsing
│   ├── bank_extract.sh    # Question extraction
│   ├── exam_generate.sh   # Intelligent exam generation
│   ├── wrongbook.sh       # Wrong question book management
│   ├── parse.sh           # Textbook parsing
│   ├── generate.sh        # Automatic question generation
│   ├── qa.sh              # Knowledge point Q&A
│   ├── search.sh          # Full-text search
│   ├── utils.sh           # Common utility functions
│   └── ocr_extract.py     # PDF OCR recognition
├── templates/             # LLM prompt templates
├── skill.json             # Claude Code skill definition
└── README.md
```

## ⚠️ Notes
1. This tool is for learning purposes only. Do not upload copyrighted textbooks, question banks, or other content to public repositories.
2. Users need to apply for their own API key before use, and API call fees are borne by the user.
3. OCR recognition and structured parsing accuracy depend on PDF quality. Text-based PDFs are recommended for best results.
