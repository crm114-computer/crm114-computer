# CRM-114 Work Protocol

## Planning & Notes
- Maintain `.plan/` directory at repo root.
- Create `index.md` linking every session file.
- Name each session file with the request timestamp (Unix epoch) and use markdown checklists.
- Capture observations, known issues, caveats, and follow-ups per session.

## Branching & Commits
- Start every session on a fresh git branch named for the session.
- Commit aggressively as work progresses; roll back if necessary.

## Development Flow
- Practice TDD: establish the plan, write failing tests that cover the tasks, then implement until tests pass.
- Maintain `docs/` with human-readable Markdown documents and cross-links.
- Add an `AGENTS.md` to each directory describing its purpose and contents.
- Keep practices language-agnostic unless requirements dictate otherwise.
