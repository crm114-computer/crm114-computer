# CRM-114 Work Protocol (Go Edition)

## Planning & Notes
- Maintain `.plan/` directory at repo root.
- Create `index.md` linking every session file.
- Name each session file with the request timestamp (Unix epoch) and use markdown checklists.
- Capture observations, known issues, caveats, and follow-ups per session.
- Ensure plans describe Go packages, modules, binaries, and expected `go test` coverage.

## Branching & Commits
- Start every session on a fresh git branch named for the session.
- Commit aggressively as work progresses; roll back if necessary.
- Keep commits scoped to specific Go modules or features whenever possible.

## Development Flow
- Practice TDD in Go: write failing Go tests (`go test ./...`) that cover the plan before implementing code.
- Maintain `docs/` with human-readable Markdown documents and cross-links that describe Go architecture and APIs.
- Add an `AGENTS.md` to each directory describing its purpose, Go packages, and modules contained within.
- Use idiomatic Go tooling (go fmt, go test, go vet) as part of every change.
- Keep practices Go-centric unless requirements dictate otherwise.
