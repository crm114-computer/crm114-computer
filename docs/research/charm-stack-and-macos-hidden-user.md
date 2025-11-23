# Charm Stack & macOS Hidden User SSH Research

## Overview
- **Goal:** Determine feasibility of a "fantasy workstation" reachable via `ssh crm114@localhost` that launches an agentic Bubble Tea terminal session using the Charm stack (Bubble Tea, Wish, Lip Gloss, Glamour, Gum, Charm tooling) and a hidden macOS user plus guided installer.
- **Outputs:** Architecture notes, install/design considerations, security caveats for README + installers.

## Charm Stack Capabilities

### Bubble Tea  (source: [Bubble Tea README](https://raw.githubusercontent.com/charmbracelet/bubbletea/master/README.md))
- Elm-inspired `Model`, `Init`, `Update`, `View` loop with asynchronous `Msg` handling -> suited for agent-driven terminals.
- Optimizations: frame-rate renderer, mouse support, focus reporting; complements large, responsive TUIs.
- Ecosystem: Bubbles (widgets), BubbleZone (mouse), Key Bubbles (key maps) to accelerate complex UI flows.

### Wish SSH Server  (source: [Wish README](https://raw.githubusercontent.com/charmbracelet/wish/main/README.md))
- Bubble Tea middleware spawns `tea.Program` per SSH session with PTY IO + resize events.
- Middleware stack allows logging (`logging.Middleware()`), PTY enforcement (`activeterm`), access control; order is LIFO.
- Built-in host-key generation + key-based auth via `gliderlabs/ssh`; avoids OpenSSH shell fallback.
- Deployment: systemd unit example; encourages dedicated service user.

### Lip Gloss  (source: [Lip Gloss README](https://raw.githubusercontent.com/charmbracelet/lipgloss/master/README.md))
- Declarative styles: colors (ANSI16/256/TrueColor), adaptive palettes per light/dark.
- Layout APIs: padding, margins, join horizontal/vertical, place, alignment; measurement helpers.
- Widgets: `table`, `list`, `tree` subpackages; renderer aware of client color profile (critical for Wish sessions).

### Glamour  (source: [Glamour README](https://raw.githubusercontent.com/charmbracelet/glamour/master/README.md))
- Markdown renderer for terminals with theme system (`dark`, `light`, custom JSON); used to show docs/status inside TUIs.

### Gum  (source: [Gum README](https://raw.githubusercontent.com/charmbracelet/gum/main/README.md))
- Shell-focused UI commands built on Bubble Tea + Lip Gloss (choose/filter/input/write/confirm/spin/log/etc.).
- Scripts capture command output to variables, enabling interactive installers resembling Homebrew.
- Styling via flags or env; consistent brand for install experience.

### Charm CLI / Services  (source: [Charm README](https://github.com/charmbracelet/charm#readme))
- Provides Charm KV/FS/Crypt/Accounts for persisting config, syncing assets, encrypting data between machines.
- Install methods: Homebrew, pacman, nix, apt/yum, releases; suits bundling in setup script.
- Self-host `charm serve` (single binary) controlling bind addresses/TLS, enabling private backends for the workstation.
- Account linking via SSH keys; keys can be backed up/imported.

## macOS Hidden User & SSH Feasibility

### Creating Hidden User (source: [Apple HT203998](https://support.apple.com/en-us/HT203998); [dscl reference](https://ss64.com/osx/dscl.html))
1. Create user with `dscl . -create /Users/crm114` and set attributes: `UniqueID` (>500), `PrimaryGroupID` (20 staff or admin), `NFSHomeDirectory` (e.g., `/var/hidden/crm114`), `UserShell /bin/zsh`.
2. Set password `dscl . -passwd /Users/crm114 <pw>` or rely on SSH keys.
3. Hide account: `sudo dscl . create /Users/crm114 IsHidden 1`.
4. Hide home folder: `sudo chflags hidden /var/hidden/crm114`.
5. Remove Public share point if present: `sudo dscl delete Local/Defaults/SharePoints/crm114\'s\ Public\ Folder/`.
6. Notes: FileVault pre-boot login may still show hidden users; ensure account isn’t added to FileVault list if invisibility desired.

### Enabling SSH/Remote Login (source: [Apple macOS Help](https://support.apple.com/en-us/guide/mac-help/mchlp1066/mac))
- Turn on **Remote Login** in System Settings → General → Sharing; limit to “Only these users” → add `crm114`.
- Apple emphasizes strong passwords, unique accounts, minimal admins, auto logout, FileVault.
- Additional hardening (not in Apple doc but from sshd_config man page):
  - Restrict sshd to loopback: edit `/etc/ssh/sshd_config` → `ListenAddress 127.0.0.1` and restart remote login.
  - Restrict users: `AllowUsers crm114@localhost` ensures only crm114 from loopback.
  - Force key auth: set `PasswordAuthentication no`, ensure `AuthorizedKeysFile` for crm114.

## Wish + Hidden User Flow
1. User runs installer (e.g., `curl -fsSL https://crm114.computer/install.sh | sh`) that:
   - Ensures dependencies (Homebrew?/Go/charm binaries) or grabs Wish/Bubble Tea app binary.
   - Creates hidden `crm114` account if absent, configures SSH, restricts to localhost.
   - Installs a launch agent/launch daemon to run Wish server under crm114, binding to localhost:22 alternative port? (If reusing macOS sshd, consider using Wish as login shell.)
2. SSH entrypoint: `ssh crm114@localhost` (or `ssh crm@localhost`) triggers either:
   - Standard sshd handing session to user shell with `~/.ssh/authorized_keys` command=... to exec Wish app; or
   - Wish running as its own SSH server on alternate port (e.g., 2222) with host user `crm`, and an SSH config alias to map `crm114.computer` to localhost:2222. Need decision.

### Option A: Use macOS sshd + shell profile
- Set user shell to Wish launcher script so login executes Wish binary automatically (no standard shell). Need to ensure Wish process inherits SSH PTY and clamps once exit.
- Keep /etc/shells updated if using custom shell.

### Option B: Run Wish daemon separately
- Wish listens on `127.0.0.1:2222`, host key stored under hidden user.
- Provide SSH config snippet: `Host fantasy-workstation
    HostName localhost
    Port 2222
    User crm
    UserKnownHostsFile /dev/null
`
- Isolation from system sshd; easier to keep Wish-specific middlewares.

## Installer Experience (Gum-driven)
- Script obtains from `https://crm114.computer/install.sh` (owned domain) to mimic `brew install` flow.
- Use Gum commands for:
  - `gum style` banner explaining actions.
  - `gum confirm` before creating hidden user / enabling SSH.
  - `gum input --password` for fallback password, or capture existing admin password via `sudo -v` (macOS prompts natively; Gum for progress messaging).
  - `gum spin --title "Creating hidden user" -- dscl ...` while running privileged steps.
  - Summaries via `gum table`/`gum log` for success states.
- Script responsibilities:
  1. Detect/ Install dependencies (Go, Wish binary, Gum if not present?). Could vendor Wish binary release.
  2. Manage `/etc/sudoers`? (Probably not.) Instead request `sudo` once.
  3. Set up launchd plist to ensure Wish service starts for hidden user at boot (maybe `LaunchAgents` running as crm114?). Need deeper research on running for hidden user (launchctl bootstrap user/<uid>?).

## Security & Operational Considerations
- Hidden user is obscurity; still enforce:
  - SSH key-only auth, `AllowUsers crm114@localhost`, `PermitRootLogin no`, disable agent forwarding if unneeded.
  - Logging: Wish logging middleware captures session metadata; also rely on macOS `system.log` for sshd.
  - Key management: Provide Gum-driven step to generate ed25519 key pair dedicated to workstation login, store under `~/.ssh/crm114_fantasy`. Optionally integrate Charm `charm link` for syncing keys.
- Maintenance: Provide uninstall or cleanup script to remove hidden user, undo sshd changes, remove Wish binaries.
- FileVault: Document that hidden user may show on FileVault screen if granted unlock rights; caution in README.

## To-Do / Open Questions
- Decide architecture (macOS sshd vs separate Wish daemon). README should explain whichever path is chosen and why.
- Determine port/host key handling for Wish if separate.
- Define actual Gum-based installer script structure and required dependencies (Gum itself could be bootstrapped via Homebrew or static binary download). Possibly vendor Gum binary or require `brew install charmbracelet/tap/gum`.
- Research launchd configuration for hidden users (login shell vs service). Need a LaunchDaemon if Wish should start regardless of login.
- Security testing: verify sshd restrict to localhost, confirm hidden user not shown in GUI (except FileVault). Document testing steps (e.g., `sudo systemsetup -getremotelogin`, `ssh localhost -p ...`).

## Suggested Documentation Deliverables
1. `docs/research/charm-stack-and-macos-hidden-user.md` (this file) capturing research.
2. Update `docs/research/index.md` with entry referencing title/date topics.
3. Future: README sections covering
   - Project purpose & architecture (Charm stack overview, Wish integration, hidden user rationale).
   - Installation guide (Gum script usage, manual steps fallback).
   - Security considerations (hidden account, SSH lockdown, FileVault note).
   - Development notes (Go modules, Wish/Bubble Tea entrypoint, tests once code exists).
