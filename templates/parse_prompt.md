# Parse Prompt
## Task
Extract structured hierarchical knowledge from the provided content, organized strictly by the original document's chapter order and structure.

## Instructions
1. Read the content carefully, identify the complete chapter hierarchy and order exactly as they appear in the document
2. Extract knowledge points grouped by their corresponding chapters
3. Add cross-chapter comparative insights for related knowledge points across different chapters
4. Return ONLY valid JSON with the following structure:
{
  "document_id": "auto_generated_unique_id",
  "title": "Full document title",
  "summary": "Comprehensive summary of the entire document",
  "total_chapters": "Total number of chapters identified",
  "tags": ["domain_tag1", "domain_tag2", "topic_tag1"],
  "chapters": [
    {
      "chapter_id": "ch_001",
      "chapter_number": "1",
      "chapter_title": "Chapter 1: XXX",
      "chapter_level": 1,
      "parent_chapter_id": null,
      "page_range": "1-15",
      "chapter_summary": "Summary of this chapter's content",
      "knowledge_points": [
        {
          "kp_id": "kp_001_001",
          "question": "Clear, testable question about the knowledge point",
          "answer": "Concise, accurate answer with source context",
          "difficulty": "basic|intermediate|advanced",
          "related_kp_ids": ["kp_001_002", "kp_003_005"]
        }
      ]
    }
  ],
  "cross_chapter_insights": [
    {
      "insight_id": "cross_001",
      "topic": "Comparison topic",
      "chapters_involved": ["ch_001", "ch_003"],
      "content": "Detailed comparative analysis between related knowledge points across chapters"
    }
  ]
}

## Rules
- STRICTLY follow the original document's chapter order and hierarchy, do not rearrange chapters
- Chapter IDs must be sequential and match the appearance order
- Each knowledge point must be tagged with its source chapter and page information
- Cross-chapter insights must explicitly reference the chapters and knowledge points being compared
- No extra text outside the JSON, ensure JSON is fully valid and properly escaped
- Questions should be specific and testable, answers must be complete and accurate
- All IDs must be unique within the document
