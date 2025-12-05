# Installer Debug Flag Plan

## Problem / Context
- Hidden-user work depends on understanding installer preflight behavior, but `install.sh` currently offers only user-facing Gum messaging.
- Agents cannot run the installer directly (per root `AGENTS.md`), so humans must capture runs and share logs.
- Without a structured debug mode, diagnosing sudo/admin checks or future provisioning steps is slow and ambiguous.

## Goals
- Introduce a `--debug` flag (and `CRM114_INSTALLER_DEBUG=1` env override) that expands logging for every major stage.
- Include exact command invocations (minus secrets), exit codes, and timing checkpoints to reconstruct execution paths.
- Ensure debug output works in both Gum and simple modes, and can be redirected to files easily.

## Non-Goals
- Do not change default installer UX for non-debug runs beyond minimal plumbing.
- No interactive debugger or REPL—focus on deterministic logs.
- Avoid introducing new dependencies beyond existing POSIX shell + Gum helpers.
- Do not rely on automated installer tests; humans capture `./install.sh --debug` output for diagnostics.

## Constraints / Assumptions
- Must honor existing Gum styling helpers; debug flag should not break colorized output.
- Debug logs must be safe to share (no passwords, tokens, or personally-identifiable info).
- Flag handling must be compatible with future subcommands (if added later).

## High-Level Approach
1. **Flag Parsing**: Teach `install.sh` to parse `--debug` before other actions, set `CRM114_DEBUG=1`, and allow environment override.
2. **Logging Helpers**: Add `debug_msg()` that respects the flag and prints timestamps + context.
3. **Instrumentation**: Wrap key functions (`set_gum_available`, `ensure_gum`, `require_sudo`, `detect_system`, future provisioning hooks) with debug logs for entry/exit and command outputs.
4. **Exit Diagnostics**: Register traps to emit debug summary on failure (e.g., last command, exit code).
5. **Documentation**: Update plan + tasks, note expected usage instructions for human operator.

## Milestones / Phases
1. **Flag + Helper Scaffolding** – implement parsing, env variable, `debug_msg`, trap.
2. **Core Instrumentation** – add debugging to existing preflight steps.
3. **Validation** – gather human-run `./install.sh --debug` transcripts to confirm instrumentation captures every stage.
4. **Hand-off Docs** – describe how to run `./install.sh --debug` and share logs.

## Risks / Tradeoffs
- Over-logging may leak sensitive info if not filtered; must carefully whitelist outputs.
- Tests may need updates to accommodate extra debug text; harness should explicitly ignore or assert debug content.
- Excessive verbosity could slow Gum rendering; ensure debug output still readable in non-interactive environments.

## Open Questions
- Should debug mode auto-enable `CRM114_INSTALLER_SIMPLE=1` to avoid Gum noise for logs? (Default assumption: no; keep modes independent.)
- Do we need log file rotation/location, or is stdout/stderr capture sufficient? (Assume stdout/stderr adequate for now.)

## Related Research
- `docs/research/hidden-user-bootstrap.md` (sudo behavior insights)

## Checklist
- [x] Parse `--debug` flag / env override and surface stage tracking
- [x] Implement `debug_msg`, stage markers, and exit/signal traps in `install.sh`
- [x] Instrument Gum bootstrap, sudo preflight/keepalive, and system detection with debug logs
- [x] Document usage expectations + cross-plan dependencies

## Linked Tasks
- `installer-debug-flag` – Add the debug flag, helper, instrumentation, plus tests.

## Status Notes
- 2025-11-28: Debug flag implemented in `install.sh`, core preflight functions instrumented, and awaiting human-provided `./install.sh --debug` run output to continue hidden-user tasks.
