# Plans Agent Guide

## Scope
- Governs every file beneath `docs/plans/` unless a more specific child directory publishes its own `AGENTS.md`.
- Obey this guide alongside the repository root rules and `docs/AGENTS.md`.

## Mission
- Keep planning artifacts authoritative: every non-trivial effort must originate here with clear goals, non-goals, tasks, and status.
- Operate autonomously, edit with exact matches, and validate work immediately after changes.

## Authoring Requirements
1. **Structure** – Plans must contain at least: Problem/Context, Goals, Non-Goals, Constraints/Assumptions, High-Level Approach, Milestones/Phases, Risks/Tradeoffs, Open Questions, Related Research references.
2. **Traceability** – Each plan must link to concrete tasks in `docs/plans/tasks.md`; every task entry must reference its plan slug.
3. **Versioning** – Instead of deleting outdated content, mark phases as complete/superseded and record rationale.
4. **Tone** – Write concise, action-oriented prose with bullet lists for decisions; cite files via `path:line` notation.

## Workflow Rules
1. **Before editing** – Review existing plans, tasks, and relevant research to avoid duplication.
2. **Creating plans** – Use human-readable slugs (`docs/plans/<slug>.md>`). Update `docs/plans/index.md` immediately with a short description.
3. **Task governance** – When plan changes imply new work, add tasks (or update statuses) in `tasks.md` during the same session; never leave plans without matching tasks.
4. **Validation** – After any modification run the applicable doc/test command (state if none). Record completion notes in the user response.

## Index & Link Maintenance
1. Treat `docs/plans/index.md` and `docs/plans/tasks.md` as authoritative: every new plan or task must be reflected there before work is considered complete; recreate the index if missing.
2. Cross-link aggressively—each plan must reference its tasks and related research, and each task must link back to its plan. Never introduce a link without verifying the target file and heading exist using `glob`/`ls` and `view`.
3. Link integrity process:
   - When adding or updating links, inspect the target file to confirm the slug/heading is present and spelled identically.
   - After edits, review diffs for link changes and revisit each referenced document to ensure anchors still match; adjust links immediately if a heading moves or is renamed.
   - When link-check tooling exists, run it; otherwise describe the manual verification performed in the user response.
4. Never fabricate references—if a target does not yet exist, create it as part of the same session (with corresponding index updates) or explicitly mark it as a TODO task.

## Checklist Discipline
1. Every plan file must include an explicit checklist section (`## Checklist`) containing Markdown checkbox items mapped to `docs/plans/tasks.md` entries; mark items as complete only when the corresponding task is finished.
2. `docs/plans/index.md` must present all plans as a checklist showing which plans are fully complete; include a checked item only when every linked task is checked.
3. `docs/plans/tasks.md` must maintain checkbox formatting for each task and stay in sync with plan checklists; update both files in the same session whenever task status changes.
4. During plan reviews, verify the checklist against real progress and add/remove items as scope evolves so the backlog stays accurate.

## Prohibitions
- No executable code or tooling instructions belong here beyond planning context.
- Never move plans outside this directory or rename slugs without updating every reference (index, tasks, linking docs).
- Do not wipe historical plans; archive sections instead.

## Handoff Expectations
- User summaries must describe affected plans, list touched files, outline task updates, and note remaining open questions or follow-up tasks.
