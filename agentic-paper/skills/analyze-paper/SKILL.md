---
name: analyze-paper
description: Analyze a research paper PDF and create structured notes for state-of-the-art positioning. Use when analyzing papers for literature review.
argument-hint: <path-to-pdf>
allowed-tools: Read, Write, Glob
---

# Paper Analysis Skill

Analyze the research paper at `$ARGUMENTS` and create structured notes for state-of-the-art comparison.

## Process

Analyze one paper at a time and finish its note before starting the next, so each note is written from that paper alone and the context does not fill up with several papers at once.

1. **Load our paper's positioning** (once per session; see "Context for Comparison" below)
2. **Read the PDF** at the provided path
3. **Read the whole reference list**, not only Related Work: the most useful follow-ups are often cited in the methods or discussion. They go in the note's "Notable References to Follow Up" table.
4. **Extract key information** following the template below
5. **Create a note file** in the `notes/papers/` directory with filename pattern: `XX_AuthorLastName_ShortTitle_VenueYear.md`
6. **Proceed to the next paper** automatically (if analyzing multiple)

## Note Template

Create a markdown file with this structure:

```markdown
# [Paper Title]

**Source:** [Journal/Conference, Year]
**Authors:** [Names]
**Affiliations:** [Institutions]
**DOI:** [DOI if available]
**PDF:** `[filename.pdf]`

---

## Introduction Summary

### Context & Motivation
[2-3 paragraphs summarizing the problem context and why it matters]

### Problem Statement
[Clear statement of the problem the paper addresses]

### Key Claims/Contributions
[Numbered list of contributions as stated by authors]

---

## State of the Art / Related Work Summary

### [Subsection Title from Paper]
[Summary of this related work area]

### [Subsection Title from Paper]
[Summary of this related work area]

[Continue for each subsection in their Related Work/SOTA section]

### Gaps Identified by Authors
[What gaps do they identify in existing work?]

---

## Technical Approach (Brief)

[1-2 paragraphs on their solution - keep concise]

---

## Quotable Passages

### For Introduction (Problem Statement)
> "[Quote that captures the problem well]"
> — Section X, p. Y

> "[Another useful quote]"
> — Section X, p. Y

### For Related Work (Gaps/Limitations)
> "[Quote about limitations of existing approaches]"
> — Section X, p. Y

> "[Quote about what's missing]"
> — Section X, p. Y

### For Positioning Our Work
> "[Quote that validates our approach or identifies need we address]"
> — Section X, p. Y

### Technical/Definition Quotes
> "[Useful definition or technical statement]"
> — Section X, p. Y

---

## Key Takeaways for Our Paper

### Relevance Assessment
- **Overall Relevance:** [HIGH/MODERATE/LOW]
- **For Introduction:** [YES/NO] - [brief reason]
- **For Related Work:** [YES/NO] - [brief reason]
- **As Comparison:** [YES/NO] - [brief reason]

### What This Paper Does Well
- [Bullet points]

### What This Paper Does NOT Address (Our Opportunity)
- [Bullet points - gaps we fill]

### How to Position Against This Paper

| Aspect | Their Approach | Our Approach |
|--------|---------------|------------------------|
| [Aspect 1] | [Their solution] | [Our approach] |
| [Aspect 2] | [Their solution] | [Our approach] |

### Suggested Citation Context
[1-2 sentences describing WHERE and HOW to cite this paper in our manuscript]

**Draft citation text:**
> "[Ready-to-use citation sentence for Related Work section]"

---

## Notable References to Follow Up

| Reference | Why Relevant | Priority |
|-----------|--------------|----------|
| [Author et al., Year - "Title"] | [Brief reason] | HIGH/MEDIUM/LOW |

---

## Assessment Summary

| Criterion | Rating | Notes |
|-----------|--------|-------|
| Relevance to our work | ⭐⭐⭐⭐⭐ | |
| Citation value | ⭐⭐⭐⭐⭐ | |
| Quote quality | ⭐⭐⭐⭐⭐ | |
| Recency | ⭐⭐⭐⭐⭐ | |

**One-line summary:** [Single sentence capturing main value for our paper]
```

## Quote Extraction Guidelines

When extracting quotes, prioritize:

1. **Problem statements** - Quotes that articulate the challenge/gap
   - Look in: Abstract, Introduction, first paragraphs of sections
   - Example patterns: "remains challenging", "lack of", "no existing solution", "gap in"

2. **Limitation statements** - Quotes about what current solutions can't do
   - Look in: Related Work, Discussion, Conclusion
   - Example patterns: "however", "limitation", "does not address", "fails to"

3. **Vision/need statements** - Quotes about what's needed
   - Look in: Introduction, Conclusion, Future Work
   - Example patterns: "need for", "requires", "must", "should enable"

4. **Definition quotes** - Clear definitions of key concepts
   - Look in: Background, Section 2
   - Example: Computing Continuum definitions

5. **Validation quotes** - Quotes that support our approach
   - Look in: Throughout
   - Quotes that align with our paper's contributions

**Quote formatting:**
- Use exact text with "..." for omissions
- Note section and page number
- Keep quotes concise (1-3 sentences max)
- Paraphrase longer passages, quote only distinctive phrases

## Context for Comparison

Every "Our approach" cell, relevance rating and positioning line compares the paper against **our paper's positioning**: a one-sentence contribution, up to three key novelties, and the topics that make a paper HIGH priority. Load it before the first paper, from the first of these that exists:

1. `.claude/references/positioning.md` in the project.
2. The project overview section of the project's `AGENTS.md`, if it states the contribution.
3. Neither: ask the user for a one-sentence contribution, up to three novelties and any HIGH-priority topics, and offer to save them to `.claude/references/positioning.md` so the next run finds them.

Keep this in the project, not in this skill: the plugin cache is version-pinned and replaced on every update.

## Topics to Flag

Mark papers as HIGH priority if they discuss a topic the positioning file lists as HIGH priority, or one directly relevant to our paper's contribution area.

## Output Location

Save extracted notes to: `notes/papers/XX_AuthorLastName_ShortTitle_VenueYear.md`

Where XX is the next available number in sequence.
