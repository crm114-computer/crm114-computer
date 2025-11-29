# Installer Detection Guard

## Status
- Completed on 2025-11-26. Detection logic with Gum messaging lives in `install.sh`, and regression coverage exists in `tests/install/detect_system_test.sh`.

## Checklist
- [x] Implement detection guards in `install.sh` (tasks: `inst-detector-baseline`, `gum-detection-ux`)
- [x] Add regression tests under `tests/install/detect_system_test.sh` (`inst-detector-tests`)
- [x] Document requirements and messaging in this plan / research references

## Problem / Context
- The installer script (`install.sh`) currently lacks environment detection, yet the project only supports contemporary Apple Silicon macOS systems.
- Running the installer on unsupported hardware or OS versions could fail unpredictably or cause user confusion.
- We need a deterministic gate that validates the platform up front and communicates requirements clearly.

## Goals
- Detect that the script is running on macOS (Darwin) with an Apple Silicon (arm64) CPU.
- Enforce a minimum supported macOS release (assume macOS 13 Ventura or later unless updated).
- Provide user-friendly failure messaging with guidance for unsupported environments.
- Expose detected system details for subsequent installer phases to consume.
- Integrate Gum-powered messaging to narrate detection outcomes with friendly language.

## Non-Goals
- Supporting Intel Macs, Linux, or Windows hosts.
- Implementing the entire installer flow (package download, configuration, etc.).
- Handling virtualization or cross-compilation scenarios.

## Constraints / Assumptions
- Target users run modern, supported macOS releases on Apple Silicon hardware.
- `uname`, `sw_vers`, and `/usr/bin/env` are available in the default macOS shell environment.
- The installer must be POSIX-sh compatible to run in `/bin/sh` on macOS.
- Gum may not be available initially; detection messaging must gracefully fall back if necessary.

## High-Level Approach
1. Gather system facts: OS name (`uname -s`), architecture (`uname -m`), and OS version (`sw_vers -productVersion`).
2. Compare results against allowed values (Darwin, arm64, minimum version >= 13.0).
3. If any check fails, print an actionable error and exit non-zero.
4. When checks pass, export structured variables (e.g., `CRM114_OS`, `CRM114_ARCH`, `CRM114_MACOS_VERSION`) for downstream use.
5. Cover edge cases such as beta version strings or unexpected command failures.
6. Use Gum helpers (from `gum-powered-installer` plan) to communicate progress with transparent, human-first language.

_Linked tasks: `inst-detector-baseline`, `inst-detector-tests`, `gum-detection-ux` in `docs/plans/tasks.md`._

## Milestones / Phases
1. **Detection spec finalization** – Confirm required checks, messages, and minimum versions.
2. **Implementation & messaging** – Add detection logic to `install.sh`, ensuring clear output and environment exports.
3. **Validation tooling** – Introduce tests or dry-run validation (e.g., unit tests via shellspec/bats or scripted fixtures) to prevent regressions.

## Risks and Tradeoffs
- macOS version comparisons can be brittle; we must normalize semantic versions carefully.
- Hard-coding minimum versions requires ongoing maintenance as Apple releases updates.
- Lack of automated shell testing may allow regressions until we invest in tooling.
- Residual risk: add version bump automation when minimum macOS requirements change.

## Open Questions
- Should the minimum macOS version be 13.x (Ventura) or 14.x (Sonoma)? For now we assume 13.x; update if product requirements differ.
- Do we need to detect Rosetta emulation explicitly, or is `uname -m` sufficient?

## Related Research
- `docs/research/gum-interface-library.md`.
