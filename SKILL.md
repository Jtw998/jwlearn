---
name: learn
displayName: Mixed Architecture Learning Assistant
description: Tool+Prompt hybrid learning assistant for document parsing, knowledge management, spaced repetition learning, and QA
version: 2.0.0
author: Claude Skill Team
---

# Learn Skill Execution Guide

You are the execution engine for the learn skill. Your job is to parse user commands and execute the corresponding bash scripts correctly.

## Available Commands & Script Mappings

### 1. parse command
**Usage**: `/learn parse --input <FILE_PATH> [--auto-add <true|false>] [--output <OUTPUT_PATH>]`
**Execute**:
```bash
bash /e/BET/.claude/skills/learn/scripts/parse.sh "<input>" <auto-add> "<output>"
```
- `--input`: Required, path to document (PDF/MD/TXT/DOCX)
- `--auto-add`: Optional, default false, whether to auto add to review deck
- `--output`: Optional, path to save parsed results

### 2. convert command
**Usage**: `/learn convert --input <SOURCE_FILE> --output <TARGET_FILE>`
**Execute**:
```bash
bash /e/BET/.claude/skills/learn/scripts/convert.sh "<input>" "<output>"
```
- `--input`: Required, source file path
- `--output`: Required, target file path (extension determines format)

### 3. review command
**Usage**: `/learn review [--limit <NUMBER>]`
**Execute**:
```bash
bash /e/BET/.claude/skills/learn/scripts/review.sh <limit>
```
- `--limit`: Optional, default 20, max number of cards to review

### 4. stats command
**Usage**: `/learn stats`
**Execute**:
```bash
bash /e/BET/.claude/skills/learn/scripts/stats.sh
```
No parameters needed.

### 5. qa command
**Usage**: `/learn qa --question "<QUESTION_TEXT>" [--document "<DOCUMENT_NAME>"]`
**Execute**:
```bash
bash /e/BET/.claude/skills/learn/scripts/qa.sh "<question>" "<document>"
```
- `--question`: Required, the question to ask
- `--document`: Optional, limit search to specific document

### 6. generate command
**Usage**: `/learn generate --source <DOCUMENT_NAME> [--count <NUMBER>] [--type <TYPE>]`
**Execute**:
```bash
bash /e/BET/.claude/skills/learn/scripts/generate.sh "<source>" <count> "<type>"
```
- `--source`: Required, document name/ID to generate questions from
- `--count`: Optional, default 5, number of questions to generate
- `--type`: Optional, default "all", question type: multiple-choice/true-false/short-answer/all

### 7. search command
**Usage**: `/learn search --keyword "<SEARCH_TERM>" [--document "<DOCUMENT_ID>"]`
**Execute**:
```bash
bash /e/BET/.claude/skills/learn/scripts/search.sh "<keyword>" "<document>"
```
- `--keyword`: Required, search term to query knowledge base
- `--document`: Optional, limit search to specific document ID

### 8. chapters command
**Usage**: `/learn chapters --document <DOCUMENT_ID>`
**Execute**:
```bash
bash /e/BET/.claude/skills/learn/scripts/chapters.sh "<document>"
```
- `--document`: Required, document ID to list chapters for

### 9. cross-chapter command
**Usage**: `/learn cross-chapter --document <DOCUMENT_ID>`
**Execute**:
```bash
bash /e/BET/.claude/skills/learn/scripts/cross_chapter.sh "<document>"
```
- `--document`: Required, document ID to get cross-chapter insights for

## Execution Rules
1. Parse the user's command and extract all parameters correctly
2. Handle optional parameters properly, use defaults when not provided
3. Make sure file paths with spaces are properly quoted
4. Execute the exact corresponding bash command
5. Show the command output to the user directly
6. If the command format is incorrect, show the help information and correct usage examples

## Help Information
If user asks for help or uses invalid command, show:
```
# Mixed Architecture Learning Assistant (Learn Skill)

Available commands:
- parse: Parse a document and extract knowledge points
  Usage: /learn parse --input <FILE> [--auto-add true|false] [--output <FILE>]

- convert: Convert document between formats
  Usage: /learn convert --input <SOURCE> --output <TARGET>

- review: Start spaced repetition review session
  Usage: /learn review [--limit <NUMBER>]

- stats: Show learning statistics
  Usage: /learn stats

- qa: Ask questions about knowledge base
  Usage: /learn qa --question "<QUESTION>" [--document "<DOCUMENT>"]

- generate: Generate practice exercises
  Usage: /learn generate --source <DOCUMENT> [--count <NUMBER>] [--type <TYPE>]

- search: Search knowledge base by keyword
  Usage: /learn search --keyword "<SEARCH_TERM>" [--document "<DOCUMENT_ID>"]

- chapters: List all chapters of a document
  Usage: /learn chapters --document <DOCUMENT_ID>

- cross-chapter: Get cross-chapter comparative insights
  Usage: /learn cross-chapter --document <DOCUMENT_ID>
```