# Gum Interface Library Evaluation

## Questions
- What capabilities does Gum provide for building conversational terminal interfaces within shell scripts?
- How can Gum enhance the installer experience with friendly, transparent messaging?
- What are the installation/runtime implications for bundling Gum with our installer on macOS Apple Silicon only?
- Which Gum commands align with our installer flows (detection, status, prompts)?
- How do other open-source projects leverage Gum components, and what patterns should we follow or avoid?

## Findings
- Gum is a CLI toolkit atop Bubbles/Lip Gloss providing UI primitives (`style`, `format`, `spin`, `input`, `choose`, `confirm`, `log`, etc.) that render ANSI-rich output directly from shell scripts without Go code.
- Distribution: single static binary (~13 MB). brew formula `brew install gum` supports macOS arm64. Alternative installs include `go install`, GitHub release tarballs, Linux repos, Windows package managers.
- Configuration: every component exposes flags (e.g., `--border`, `--width`) and corresponding environment variables (`GUM_STYLE_BORDER`, `GUM_CONFIRM_DEFAULT`) for global theming. Patterns from Charm examples favor defining palette env vars once per script.
- Gum degrades well when stdout is not a TTY; commands still emit plaintext—use `gum format --theme` for stylized Markdown or `gum log --structured` for machine-friendly transparency logs.

### Component Catalog & Recommended Usage
| Component | Purpose | When to Use | Notes |
| --- | --- | --- | --- |
| `style` | Pretty text blocks with borders, padding, colors | Narration cards, success/failure banners, section dividers | Combine with helpers (e.g., `say`, `celebrate`) for consistent tone |
| `format` | Render Markdown, templates, emoji | Long-form explanations, instructions | `gum format -t template` enables termenv helpers (`Bold`, `Color`) |
| `log` | Structured logging with levels | Transparency feed (info/debug/error) | Supports `--structured` JSON-ish output; align with installer telemetry |
| `spin` | Spinner with optional subprocess execution | Download/install steps, network checks | `gum spin --title "Downloading" -- brew install ...` and optionally `--show-output` |
| `confirm` | Yes/No prompts | Destructive actions, optional installs | Customize `--affirmative/--negative` for friendlier copy |
| `choose` | Menu selection (single/multi) | Feature toggles, component selection | `--limit N` or `--no-limit` for multi picks; Basecamp’s omakub uses this for optional packages |
| `filter` | Fuzzy finder | Large lists (git branches, history) | Combine with `xargs` to pass selection downstream |
| `input` / `write` | Single-line vs. multi-line input | Ask for names, tokens, config | Use `--placeholder`, `--password`; `write` supports `Ctrl+D` to finish |
| `join` | Compose multiple styled blocks | Layout builder for cards | Works well with `style` to assemble headers/footers |
| `table` | Select rows from CSV-like data | Display options with columns | Good for summarizing environment checks |
| `pager` | Scroll long text | Show licenses, release notes | Honor `$PAGER` semantics when needed |
| `file` | File picker | Let user select config/profile file | Example: `$EDITOR $(gum file)` |

### Patterns from Open Source Usage
- **Charm’s git-branch-manager example** (`examples/git-branch-manager.sh`): defines `git_color_text()` helper wrapping `gum style` and centralizes palette constants (`GIT_COLOR`). Branch selection uses `gum choose --selected.foreground` to keep highlight color consistent.
- **Basecamp omakub installer** (`install/first-run-choices.sh`, `bin/omakub-sub/menu.sh`): uses `gum choose --no-limit --header` for onboarding checklists and `gum input` for parameter collection. They pipe results through `tr`/`cut` before exporting env vars—good reminder to sanitize Gum output before subsequent commands.
- **Charm commitment examples** (`examples/commit.sh`, `examples/test.sh`): demonstrate chaining `gum input` and `gum write` for multi-step data collection, pairing `gum confirm` before executing `git commit`. Shows a pattern of storing Gum output in shell vars for reuse.
- **Community dotfiles scripts** (e.g., git branch managers): guard Gum usage with `command -v gum` checks and fallback messages to avoid breaking automation.

### Implementation & Usage Guide for Installer Scripts
1. **Dependency bootstrap**: call `command -v gum` early. If absent, detect Homebrew with `command -v brew`; offer to install Gum (`brew install gum`) using `gum spin` for progress when Gum becomes available (fallback to plain text during bootstrap).
2. **Helper layer**: define shell functions (`say`, `celebrate`, `warn`, `ask_confirm`, `with_spinner`) that internally call Gum commands when available, else default to `printf`. This keeps the main logic agnostic to Gum presence.
3. **Narrative scripting**:
   - Use `gum style --border rounded --align left --width 70` for “story cards” describing each phase.
   - Use `gum log --level info` for transparency logs (e.g., “Looking for X”). Reserve `--level warn/error` for actionable issues.
4. **Progress handling**: wrap long operations with `gum spin --spinner dot --title "Downloading dependencies" -- command`. Capture command output to log after spinner completes to keep users informed.
5. **Prompts**: when decisions are needed (optional components, telemetry opt-in), prefer `gum choose` or `gum confirm` with explicit friendly language (“Yes, bring it on” vs. “No, maybe later”). For multi-select choices, set `--height` to avoid cramped menus and include `--header` text that frames the decision.
6. **Accessibility / fallbacks**: detect non-interactive shells via `[ -t 1 ]` before invoking Gum components that require cursor interaction (`choose`, `filter`). Provide an escape hatch (e.g., env flag) that forces plain echo/log output.
7. **Styling consistency**: store palette values in env vars (e.g., `CRM114_COLOR_PRIMARY='#5CFFC7'`) and pass them to Gum flags. Align with Charm palette or brand guidelines.
8. **Testing**: for automated validation, script Gum commands with `GUM_CHOOSE_SELECTED` env var to preselect options or use `printf` piped into Gum to simulate input.

## Options Considered
1. **Adopt Gum for all installer interactions**
   - Pros: Rich UI quickly, consistent styling, minimal effort.
   - Cons: Adds binary dependency, requires ensuring Gum is installed before script runs.
2. **Custom POSIX shell UI**
   - Pros: Zero new dependencies.
   - Cons: Limited styling, more code to maintain, harder to achieve delightful UX.
3. **Use other TUIs (e.g., whiptail, dialog)**
   - Pros: Common in Linux distros.
   - Cons: Not native to macOS, less modern styling.

## Decision / Recommendation
- Gum excels at providing a human-friendly installer interface: the CLI primitives cover narration, progress feedback, and user prompts with minimal code.
- Homebrew installation plus standalone binaries make it practical to depend on Gum in macOS-centric workflows.
- Applied in crm114 installer: `install.sh` now uses Gum for logging, spinners, and friendly status blocks; verification now relies on human-operated `install.sh --debug` transcripts instead of automated installer tests.

## References / Links
- Gum README & command docs: https://github.com/charmbracelet/gum
- Gum example scripts: `examples/git-branch-manager.sh`, `examples/commit.sh`, `examples/test.sh`, `examples/demo.sh`
- Basecamp omakub menu scripts: https://github.com/basecamp/omakub (uses Gum for onboarding choices)
- Community dotfiles (e.g., https://github.com/andrew8088/dotfiles/blob/main/scripts/gbm.sh) illustrating helper-based Gum usage
