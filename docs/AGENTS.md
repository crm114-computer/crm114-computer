# Docs Agent Guide

## Scope
- Applies to every file inside `docs/` unless a deeper directory provides its own `AGENTS.md`.
- Layer these rules on top of the repository-root `AGENTS.md` and any directory-specific guidance.

## Operating Principles
- Read every file immediately before editing it and mirror its formatting exactly.
- Omit pleasantries, and avoid unnecessary questions—act autonomously.
- Never add inline code comments unless explicitly instructed; communicate decisions through the documents themselves.
- Treat documentation work as part of an approved plan: coordinate with `docs/plans/index.md` and `docs/plans/tasks.md` before and after changes.
- After modifying files, run the most specific validation or documentation-check command available and report the outcome (state “no automated check” if none exists).
- Never commit, merge, or push unless the user explicitly requests it.

## Authoring Standards
1. Use Markdown with consistent heading levels and blank lines between sections.
2. Keep content outcome-oriented—highlight decisions, status, and next steps.
3. Reference code or docs using the `path:line` format.
4. Prefer short paragraphs or bullet lists; call out assumptions and open questions explicitly.

## Workflow
1. **Discovery** – Inspect the `AGENTS.md` chain and existing nearby docs for context before editing.
2. **Planning Hooks** – When work creates or modifies plans, update `docs/plans/index.md` and `docs/plans/tasks.md` in the same session.
3. **Research Hooks** – When recording investigations, create or update entries under `docs/research/` and link them from `docs/research/index.md` if present.
4. **Validation** – After saving, execute the relevant documentation/test command (or note that none applies) and include results in the user response.

## Index & Linking Discipline
1. Maintain every index under `docs/` (e.g., `docs/plans/index.md`, `docs/research/index.md`) whenever documents are added, renamed, or retitled. If an expected index is missing, create or restore it before continuing.
2. Cross-link related documents aggressively; every reference must cite an existing file and heading, and new documents must link back to the relevant plan/task entries.
3. Link verification process:
   - Before adding a link, confirm the file exists with `glob`/`ls` and open it with `view` to verify the anchor text.
   - After edits, review the diff for link changes and re-open each target to ensure the referenced heading still exists; update links immediately if targets moved.
   - When automated link-check tooling is available, run it; otherwise document the manual verification performed in your user response.

## Prohibitions
- Do not relocate planning or research artifacts outside `docs/`.
- Do not delete historical plans, tasks, or research without explicit approval; mark them complete or superseded instead.
- Do not introduce executable code under `docs/` (examples must be fenced code blocks only).

## Handoff Expectations
- Summarize documentation changes, list touched files, and reference associated tasks when replying to the user.
- Highlight follow-up work as candidate tasks so the backlog stays accurate.
