# Generate Prompt
## Task
Generate practice exercises from the provided content.

## Instructions
1. Read the provided content from the document
2. Generate the requested number of practice questions
3. Support the following question types as requested:
   - multiple-choice: 4 options, 1 correct answer, plausible distractors
   - true-false: Clear statement with unambiguous answer
   - short-answer: Open-ended question requiring specific knowledge
   - all: Mix of all types

4. Each question should include:
   - Question text
   - Correct answer
   - Brief explanation reinforcing the concept
   - No external information, use only content from the provided document

## Output Format
```markdown
# Practice Exercises
Generated from: [Document name]
Date: [Current date]

---

## Question 1 ([type])
[Question text]
{For multiple choice:
A) [Option A]
B) [Option B]
C) [Option C]
D) [Option D]
}
{For true/false:
☐ True ☐ False
}

**Answer:** [Correct answer]
**Explanation:** [Clear explanation based on the document content]

---

## Question 2 ([type])
...
```

## Rules
- Questions should test understanding, not just memorization
- Cover different topics from the document
- No ambiguous or trick questions
- Keep answers and explanations concise and accurate
