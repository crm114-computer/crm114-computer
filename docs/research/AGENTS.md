# Research Agent Guide

## Scope
- Applies to every artifact under `docs/research/` unless a subdirectory introduces stricter rules.
- Layer these rules atop the repository root and `docs/AGENTS.md` directives.

## Purpose
- Capture investigations, experiments, benchmarks, and external findings that inform plans.
- Keep research independent from planning: do **not** include next steps, tasks, or action items in research entries.

## Authoring Standards
1. Use Markdown with sections at minimum: Questions, Findings, Options Considered, Decision/Recommendation, References/Links.
2. Highlight metrics, commands, and evidence with fenced code blocks or tables.
3. Reference related plans/tasks using their slugs and `path:line` notation where relevant.
4. Keep chronological clarity—timestamp major updates or add concise changelog bullets.

## Workflow
1. Before writing, scan existing research to avoid duplication; update prior entries when extending a topic.
2. When new research begins, create `docs/research/<slug>.md` and add it to any research index if present.
3. Summaries may reference related plans/tasks for context, but **must not** prescribe next actions or planning directives; research stands on its own.
4. After editing, run applicable validation/test commands (or state that documentation-only changes have no runnable tests) and report results in your response.

## Index & Link Maintenance
1. Maintain `docs/research/index.md` (create or repair it if missing) so every research file is discoverable with a brief description.
2. Cross-link findings to the plans/tasks they inform and ensure reciprocal links exist back to the research entry.
3. Link verification discipline:
   - Before inserting a link, confirm the target file and heading exist via `glob`/`ls` and `view`.
   - After editing, review link-related diffs and re-open each referenced document to ensure anchors still match the headings; update immediately if anything moved.
   - When automated link-checks exist, run them; otherwise describe manual verification steps in the user response.
4. Never invent references—if the linked document does not yet exist, create it (with corresponding index entries) or add a clearly tracked TODO task.

## Prohibitions
- Do not remove historical findings; append updates or mark them superseded.
- Avoid speculative content without evidence—flag assumptions explicitly.
- No source code or secrets belong here; redact sensitive data before inclusion.

## Handoff Expectations
- User updates must enumerate changed research files and key decisions.
- Research outputs can inspire future planning discussions, but do **not** add tasks or next steps directly from research.
