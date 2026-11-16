# Generative AI Leader Certification Prep Article Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write a standalone Jekyll post that prepares candidates for the Google Cloud Certified - Generative AI Leader certification.

**Architecture:** Use the supplied pocket guide as an outline and the cloud architect prep post as a style reference. Verify current or volatile claims through official Google Cloud sources, then write a focused exam guide with domain-oriented explanations, selection heuristics, comparison tables, and an actionable study plan.

**Tech Stack:** Markdown, Jekyll front matter, existing `make build` site workflow.

---

## File map

- Create `_posts/2026-11-15-gcp-generative-ai-leader-prep.md`: the reader-facing certification article.
- The source guide is `/Users/bachir/Downloads/Google Cloud Generative AI Leader Certification_ Comprehensive Pocket Study Guide.md`; use it for content only and do not link to its local path.
- Use `_posts/2026-07-05-gcp-cloud-architect-prep.md` as the tone and format reference. No site-wide files or companion code are in scope.

### Task 1: Verify exam and product references

**Files:**
- Read: `/Users/bachir/Downloads/Google Cloud Generative AI Leader Certification_ Comprehensive Pocket Study Guide.md`
- Read: `_posts/2026-07-05-gcp-cloud-architect-prep.md`

- [ ] Check the official Google Cloud certification page and exam guide for current exam format, domains, weights, and official candidate preparation resources.
- [ ] Check official Google Cloud product documentation for names and distinctions used in the solution selection sections, including Gemini, AI Studio, Vertex AI, grounding, and agent tooling.
- [ ] Exclude or qualify any pocket-guide assertion not supported by current official sources; do not repeat unsupported exam tips as official policy.

### Task 2: Draft the article

**Files:**
- Create: `_posts/2026-11-15-gcp-generative-ai-leader-prep.md`

- [ ] Add front matter matching local posts: `layout: post`, `comments: true`, a reader-facing title and concise excerpt, `categories: certification`, relevant GCP/GenAI/certification tags, `toc: true`, and `img_excerpt:`.
- [ ] Write an opening that explains the leadership and business-decision focus of the exam, then give readers an exam mindset and scenario-reasoning checklist.
- [ ] Cover the core concepts and practical distinctions candidates need: generative AI/model capabilities, fit-for-purpose model choice, grounding and retrieval, agents, responsible AI/security/governance, and value measurement.
- [ ] Use compact tables and decision heuristics to make choices memorable. Keep implementation-level details and volatile product specifications out unless official sources show they are exam-relevant.
- [ ] Close with a focused preparation sequence and links to official exam and learning resources.
- [ ] Keep the article standalone, in the existing blog voice, and free of private paths or source-task mechanics.

### Task 3: Validate and review

**Files:**
- Review: `_posts/2026-11-15-gcp-generative-ai-leader-prep.md`

- [ ] Run `git diff --check` from `/Users/bachir/co/github/dzlab/dzlab.github.io`; expect no whitespace errors.
- [ ] Run `make build` from the blog repository; expect the Jekyll build to complete successfully.
- [ ] Review the final diff for front matter, official links, current product naming, claim support, and consistency with the approved design.
