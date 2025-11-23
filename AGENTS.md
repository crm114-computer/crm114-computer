# CRM-114 Work Protocol (Go Edition)

## Planning & Notes
- Maintain `.plan/` directory at repo root.
- Create `index.md` linking every session file.
- Name each session file with the request timestamp (Unix epoch) and use markdown checklists.
- Capture observations, known issues, caveats, and follow-ups per session.
- Ensure plans describe Go packages, modules, binaries, expected `go test` coverage, required research deliverables, and testing strategy.
- Complete every plan item before ending a session; if something cannot be done without a user answer, move it to `## Won't Do` with a justification and required follow-up.
- Never leave unchecked tasks in any plan file; conclude with `## Debrief` summarizing per-task outcomes, executed tests (with pass/fail status), research artifacts, git activity, and merge status.

## Branching & Commits
- Start every session on a fresh git branch named for the session.
- Commit aggressively as work progresses; roll back if necessary.
- Keep commits scoped to specific Go modules or features whenever possible.
- Track all git activity (branch creation, commits, merges) and include a summary in the plan debrief and user response.

## Git & Merge Policy
- Handle merging session branches back to `main` yourself once all tests pass and the project remains green.
- Never merge with failing or unrun tests; document blockers in the plan's `## Won't Do` section and continue on the branch until resolved.
- Keep `main` stable; re-run full suites post-merge when merges occur.

## Development Flow
- Practice TDD in Go: write failing Go tests (`go test ./...`) that cover the plan before implementing code.
- Maintain `docs/` with human-readable Markdown documents and cross-links that describe Go architecture and APIs.
- Add an `AGENTS.md` to each directory describing its purpose, Go packages, and modules contained within.
- Use idiomatic Go tooling (go fmt, go test, go vet) as part of every change, recording results in the plan debrief.
- Keep practices Go-centric unless requirements dictate otherwise.

## Research Protocol
- Store all research artifacts in `docs/research/`, organized by topic and date.
- Each research request requires a professionally written Markdown document with deep technical hierarchy, diagrams (if applicable), and references.
- Maintain `docs/research/index.md` as a table of contents linking to every research document.
- Keep research scoped to developer/agent audiences; include actionable conclusions for Go implementation.
- Share the complete research document contents with the user alongside the session debrief.

## Response Protocol
- Upon completing a request, send the entire session plan file (including checklist, `## Won't Do`, and `## Debrief`) to the user along with a concise summary.
- Explain every checklist item in the response, highlighting code, docs, tests, and research artifacts touched.
- Include executed test commands with pass/fail status and reasoning for any failures.
- Provide a summary of all git operations performed (branches created, commits authored, merges executed or deferred) and reference merge blockers if applicable.
