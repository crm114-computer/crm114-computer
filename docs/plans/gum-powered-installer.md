# Gum-Powered Installer Experience

## Status
- Completed on 2025-11-26. Gum helpers, messaging, and spinners shipped in `install.sh`, and supporting documentation/tests are in place.

## Checklist
- [x] Capture Gum capabilities and storytelling patterns (`gum-storytelling-guidelines`)
- [x] Bootstrap Gum dependency detection/installation in `install.sh` (`gum-bootstrap`)
- [x] Build helper toolkit + fallbacks for status, success, warnings, and spinners (`gum-helper-toolkit`)
- [x] Apply Gum UX to detection and progress flows (`gum-detection-ux`, `gum-progress-phases`)
- [x] Document tone/pattern guidelines in plan + research

## Problem / Context
- Our installer currently performs environment detection but lacks a deliberate, human-friendly interface.
- We need consistent storytelling, transparency, and prompts throughout the installer flow to build trust with users.
- Charmbracelet's Gum library provides rich terminal UI primitives suited for our macOS-only, Apple Silicon audience.
- Expanded research (`docs/research/gum-interface-library.md`) now enumerates Gum components, best practices from open-source usage, and guidance on when to apply each primitive. This plan must incorporate those insights into actionable work.

## Goals
- Integrate Gum as the UX layer for `install.sh`, covering narration, prompts, confirmation, and progress feedback.
- Detect the presence of Gum and bootstrap it seamlessly (e.g., auto-install via Homebrew) when missing.
- Craft friendly, human-first messaging describing each installer phase, including detection, dependency setup, and future steps.
- Ensure Gum usage remains POSIX-sh compatible and resilient to non-interactive shells where possible.
- Establish helper abstractions (e.g., `say`, `celebrate`, `warn`, `with_spinner`, `ask_confirm`) that encapsulate Gum behavior informed by our research catalog.

## Non-Goals
- Building a standalone GUI or native macOS app.
- Supporting non-macOS platforms or shell environments lacking ANSI support.
- Replacing other installer logic beyond messaging and user interaction.

## Constraints / Assumptions
- Target systems have Homebrew available or can install Gum manually; we can guide users if not.
- Gum binary usage must not block automated runs; provide a fallback/log-only path when `gum` is unavailable and cannot be installed.
- Installer is invoked from `/bin/sh`, so gum invocations must be compatible with POSIX shell semantics.
- Some stages may run in non-interactive contexts; helpers must detect `$TERM` / `isatty` and downgrade gracefully.

## High-Level Approach
1. Add a Gum dependency check near the start of `install.sh`; if absent, prompt the user (via plain echo) to install automatically (via `brew install gum`) or abort with guidance.
2. Introduce helper functions (e.g., `say`, `celebrate`, `warn_wait`, `with_spinner`, `ask_choice`) that wrap Gum commands (style/log/spin/choose) and fall back to plain text based on availability or non-interactive mode.
3. Replace existing `printf` outputs with Gum-powered components for detection successes/failures and future installer steps, following the component usage guidelines captured in research.
4. Document Gum integration details and friendly language guidelines within this plan and related tasks; keep palette values centralized for consistent styling.

## Milestones / Phases
1. **Research & Design** – Capture Gum capabilities, decide on messaging patterns (completed via `docs/research/gum-interface-library.md`).
2. **Dependency Bootstrap** – Implement Gum presence check/install flow in `install.sh`.
3. **Helper Toolkit & Detection UX** – Port system detection messaging to Gum with transparent narratives using helper functions.
4. **Expanded UX** – Apply Gum components (spinners, confirmations, choices) to future installer phases guided by the research playbook.
5. **Storytelling Guidelines** – Formalize tone/phrasing conventions referencing Gum capabilities for future contributors.

## Storytelling Guidelines
- **Tone**: Keep sentences short, neutral, and specific. Prefer plain verbs (“Checking system requirements…”) over hype or colloquialisms. Limit each Gum block to a single idea.
- **Structure**: Follow a three-part pattern—context, action, result. Example: “Verifying macOS version…”, “Running dependency check…”, “All checks passed.”
- **Component use**: Use the neutral helper (`info`) for status, success helper for confirmations, and reserve warning/error styling for actionable problems. Keep `gum style` borders simple (`normal`) and width ≤ 72 characters for readability.
- **Transparency**: Mention the command or resource involved when possible (“Installing Gum via Homebrew”). Pair longer operations with `gum spin --show-output` when logs matter.
- **Fallback awareness**: Every message must remain clear when Gum falls back to plain text. Avoid visual-only cues; repeat key status words (e.g., “WARNING:” prefix) in the copy itself.

## Risks and Tradeoffs
- Auto-installing Gum assumes Homebrew availability; fallback messaging must handle missing brew gracefully.
- Heavy styling may hinder accessibility for some users; include plain-text fallbacks when Gum cannot run.
- Future non-interactive/CI usage might require a "no-Gum" mode.
- Reliance on Gum-specific UX patterns could complicate test automation; need scripted overrides or environment variables for deterministic tests.

## Open Questions
- Should we vendor Gum binaries or rely solely on Homebrew/network access?
- Do we need localization or accessibility adjustments beyond friendly English messaging?
- How should future modules expose Gum helpers (single script vs. sourced library) for reuse across tooling?

## Related Research
- `docs/research/gum-interface-library.md` – includes component catalog, best practices, and implementation guidance.

## Linked Tasks
- `gum-bootstrap` – Ensure Gum dependency management in installer.
- `gum-detection-ux` – Reskin detection flow using Gum messaging.
- `gum-storytelling-guidelines` – Document language patterns for installer output.
- `gum-helper-toolkit` – Build helper functions (say/celebrate/warn/spinner/prompts) and ensure fallbacks.
- `gum-progress-phases` – Apply Gum spinners/logs to future installer steps beyond detection.
