# Tests Path Removal Plan

## Problem / Context
- Historical scripts and docs reference a legacy tests directory (`tests/...`), but the repository no longer exposes that path, producing confusion and failed instructions for operators following current guidance.
- These stale references appear across installer tooling, docs, and helper scripts; without systematic removal they continue to mislead future contributors.
- No active plan owns this cleanup, so work has drifted outside the documented backlog.

## Goals
- Eliminate every legacy tests path reference across code, scripts, and documentation.
- Replace or rewrite affected instructions so humans know the correct locations or commands.
- Add regression guards (lint/tests or CI checks) to block future reintroduction of the deprecated path string.

## Non-Goals
- Creating new end-to-end test harnesses (only scrub/redirect existing references).
- Renaming legitimate directories that merely contain the substring "tests" but serve other purposes.
- Broader refactors of install tooling beyond the minimal edits needed to remove the stale path.

## Constraints / Assumptions
- All work must respect existing installer safeguards and not execute privileged scripts directly.
- Replacement paths must point to currently valid locations in the repo (e.g., `tests/install/` assets now relocated elsewhere) or remove instructions entirely if obsolete.
- Changes must maintain repository documentation standards (per `docs/AGENTS.md`).

## High-Level Approach
1. **Inventory** — Globally search for references to the legacy tests directory (usually written as `./tests/...`), categorize by file type, and decide per-instance remediation (redirect vs. deletion).
2. **Scrub & Update** — Edit each affected file, ensuring replacements preserve formatting and meaning; update docs to describe new locations or workflows.
3. **Guardrail** — Add a lightweight check (e.g., grep-based test) that fails when the deprecated tests path resurfaces.

## Milestones / Phases
1. **Reference Inventory** — Produce definitive list of files referencing the deprecated tests path (including any `./tests/...` variants) and expected fixes.
2. **Repository Scrub** — Apply edits across code/docs removing or updating the path.
3. **Regression Guard** — Introduce automated enforcement to keep the deprecated path out.

## Risks / Tradeoffs
- Aggressive string removal might break legitimate shell examples if replacements are incorrect.
- Guardrails that run on every build could add CI time; must stay lightweight.
- Missing a hidden reference would undermine trust; thorough search discipline required.

## Open Questions
- Should replacements point to a new canonical tests directory or drop the instructions entirely?
- Are there external consumers depending on the deprecated path that need migration guidance?

## Related Research
- None yet.

## Checklist
- [ ] Remove every legacy tests path reference and verify replacements (`tests-path-scrub`).
- [ ] Add automated enforcement preventing reintroduction (`tests-path-guard`).

## Linked Tasks
- `tests-path-scrub` — Remove every legacy tests path reference (including any `./tests/...` mentions) and update instructions.
- `tests-path-guard` — Add regression guard to block future legacy tests path usage (including `./tests/...`).
