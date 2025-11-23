# crm114 Fantasy Workstation Installer Plan

## Objective
Design a single-shot installer (delivered via `https://crm114.computer/install.sh`) that provisions a hidden macOS account named `crm114`, locks SSH access to localhost with key-only auth, installs Charm-stack dependencies via Homebrew, and ensures `ssh crm114@localhost` launches the project’s Wish/Bubble Tea UI.

## Requirements Recap
1. Create hidden user `crm114` with home dir `/Users/.crm114` (`IsHidden=1`, home folder hidden). *(Apple HT203998)*
2. Enable Remote Login (SSH) and prompt for sudo; restrict access to `crm114` only. *(Apple macOS Help: Remote Login)*
3. Set up passwordless SSH by generating keys and disabling password auth for `crm114`. *(sshd_config man page)*
4. Provision dependencies under the `crm114` account via Homebrew (Wish binary, Gum, Go toolchain, project assets).
5. Wire Wish so every SSH session spawns the project TUI automatically. *(Wish README)*

## Workflow Overview
| Phase | Actions | Tooling |
| --- | --- | --- |
| 0. Bootstrap | Fetch Gum (if absent), display consent banner, capture telemetry opt-in. | Gum `style`, `log`, `confirm` |
| 1. Privilege prep | `sudo -v`, keep-alive loop, validate macOS version (`sw_vers`). | shell + Gum `spin` |
| 2. Hidden user | Create `/Users/.crm114`, `dscl` attributes, hide account/home, random strong password. | `dscl`, `chmod`, `chown`, `chflags` |
| 3. SSH service | `systemsetup -setremotelogin on`, `dseditgroup` add user, edit `/etc/ssh/sshd_config` (backup first) to bind `127.0.0.1`, add `Match User crm114` block enforcing keys + ForceCommand. Restart sshd. | `plutil`, `launchctl`, Gum `spin` |
| 4. Key mgmt | Generate local key pair (`~/.ssh/crm114_fantasy`), copy pubkey into `/Users/.crm114/.ssh/authorized_keys` with strict perms, record fingerprint. | `ssh-keygen`, `install`, Gum `table` |
| 5. Homebrew deps | Ensure Homebrew exists (install if missing), then `sudo -u crm114 -H /opt/homebrew/bin/brew install charmbracelet/tap/wish charmbracelet/tap/gum go charm`. Optionally use `brew bundle`. | Homebrew |
| 6. Wish wiring | Build or download project Wish binary into `/usr/local/libexec/crm114/fantasy`. Create wrapper shell (`/usr/local/bin/crm114-shell`) that execs binary; add to `/etc/shells` and set as `UserShell`. Provide launchd plist for background updates if needed. | Go build, Wish middleware, `launchctl` |
| 7. Validation | `ssh -F ~/.ssh/crm114_config crm114@localhost` dry-run, ensure session shows Bubble Tea UI, confirm password login denied, log summary. | `ssh`, Gum `log`, `confirm` |
| 8. Rollback hooks | Optional `crm114.computer/uninstall.sh` link; record backups of modified files. | shell |

## Detailed Plan

### 0. Bootstrap & UX (Gum-driven)
- Detect Gum; if absent, temporarily download static Gum binary to `/tmp` for installer UI (then offer to install via Homebrew later).
- Present overview using `gum style --border double --margin "1 2"` summarizing actions (hidden user, SSH changes, Wish install).
- Collect confirmation (`gum confirm --default=false`). Abort safely if declined.

### 1. Privilege Preparation
- `gum spin --title "Requesting sudo" -- sudo -v` to prompt once. Background keep-alive: `while true; do sudo -n true; sleep 45; done &` (record PID for cleanup).
- Ensure script runs on macOS 13+ (check `sw_vers -productVersion`). Abort with guidance otherwise.
- Determine CPU architecture (`uname -m`) to pick correct Homebrew prefix (`/opt/homebrew` vs `/usr/local`).

### 2. Hidden User Creation (`/Users/.crm114`)
- Create home dir: `sudo install -d -m 700 /Users/.crm114`.
- `sudo dscl . -create /Users/crm114`, set:
  - `UniqueID` = next available >= 550.
  - `PrimaryGroupID` = 20 (staff) or custom admin group if elevated tools needed.
  - `UserShell` = placeholder `/bin/zsh` (will change later).
  - `NFSHomeDirectory` = `/Users/.crm114`.
  - `RealName` = "CRM114 Workstation".
- Set password to random string (store only for admin reference) or disable by `PasswordAuthentication no` + `sudo pwpolicy -u crm114 -sethashtypes SMB-NT on` optional. Document location of generated password (e.g., `/var/root/.crm114_creds`).
- Hide user: `sudo dscl . create /Users/crm114 IsHidden 1`.
- Hide home: `sudo chflags hidden /Users/.crm114`.
- Remove Public share: `sudo dscl delete Local/Defaults/SharePoints/CRM114\'s\ Public\ Folder 2>/dev/null || true`.

### 3. Remote Login & SSH Hardening
- Enable remote login: `sudo systemsetup -setremotelogin on`.
- Restrict allowed users: `sudo dseditgroup -o edit -a crm114 -t user com.apple.access_ssh` and optionally remove "everyone".
- Backup config: `sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.crm114.bak.$(date +%s)`.
- Apply edits (use `plutil` or `sed` with heredoc) to ensure:
  ```
  ListenAddress 127.0.0.1
  PasswordAuthentication no
  ChallengeResponseAuthentication no
  PubkeyAuthentication yes

  Match User crm114
      AllowTcpForwarding no
      X11Forwarding no
      ForceCommand /usr/local/libexec/crm114/wish-login
  ```
- Validate syntax: `sudo sshd -t -f /etc/ssh/sshd_config`.
- Restart service: `sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist && sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist` (or `sudo launchctl kickstart -k system/com.openssh.sshd`).

### 4. SSH Key Provisioning
- Local machine: if `~/.ssh/crm114_fantasy` missing, run `ssh-keygen -t ed25519 -f ~/.ssh/crm114_fantasy -C "crm114 fantasy workstation" -N ""` (wrap with Gum spinner).
- Ensure `~/.ssh/config` entry:
  ```
  Host crm114-local
      HostName localhost
      User crm114
      IdentityFile ~/.ssh/crm114_fantasy
      IdentitiesOnly yes
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
  ```
- Create `.ssh` for hidden user: `sudo -u crm114 install -d -m 700 /Users/.crm114/.ssh`.
- Append public key via `cat ~/.ssh/crm114_fantasy.pub | sudo tee /Users/.crm114/.ssh/authorized_keys >/dev/null` and `sudo chmod 600 ...`.
- Optionally support additional agent keys by prompting (Gum `file` or `input`).

### 5. Homebrew Dependencies for crm114
- Ensure Homebrew installed globally; if not, prompt to run official install script (requires user approval). Use Gum to show commands executed.
- Export `HOMEBREW_NO_ANALYTICS=1` etc.
- Switch to hidden user context: `sudo -u crm114 -H env PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" brew install charmbracelet/tap/wish charmbracelet/tap/gum charmbracelet/tap/glow go`.
- (Optional) Use `brew bundle --file=/tmp/crm114.Brewfile` for repeatability.
- Install project binary: either
  - Build from source repo (if local) via `go build ./cmd/fantasy` and place into `/usr/local/libexec/crm114/fantasy`, or
  - Download release tarball from `crm114.computer/releases/...` and verify shasum.
- Ensure directory `/usr/local/libexec/crm114` exists and is `root:wheel 755` (binaries inside 755).

### 6. Wish-Based Login Wiring
- Create wrapper script `/usr/local/libexec/crm114/wish-login` owned root, mode 755:
  ```bash
  #!/bin/zsh
  export CRM114_HOME="/Users/.crm114"
  exec /usr/local/libexec/crm114/fantasy --config $CRM114_HOME/.config/crm114/config.yaml
  ```
- Register script as valid shell: append `/usr/local/libexec/crm114/wish-login` to `/etc/shells` if not already.
- Update user shell: `sudo chsh -s /usr/local/libexec/crm114/wish-login crm114`.
- Wish binary responsibilities:
  - Use Wish Bubble Tea middleware to render UI per SSH session.
  - Log sessions via Wish logging middleware to syslog or file under `/Users/.crm114/logs` (rotate with `newsyslog`).
  - Optionally integrate Charm KV/FS for syncing workspace data.
- Provide launchd agent (optional) under `/Library/LaunchDaemons/com.crm114.refresh.plist` if background tasks needed (e.g., update Wish binary). Not required for direct SSH entry because Wish runs per session via ForceCommand.

### 7. Validation & Reporting
- Use Gum `log` to show checklist as script proceeds; mark success/failure states with `gum log --level success ...` etc.
- Automated checks:
  1. `ssh -F ~/.ssh/crm114_config crm114@localhost 'exit'` expecting Wish to exit gracefully (non-zero exit acceptable if controlled). For UI check, prompt user to manually connect at end.
  2. Attempt password auth (expect failure): `ssh crm114@localhost` without key → should fail quickly.
  3. Confirm `id crm114` shows expected UID/GID.
  4. Run `sudo launchctl print system/com.openssh.sshd | grep ListenAddress` verifying `127.0.0.1`.
- Summarize results using Gum `table` listing each concern (user creation, SSH, keys, Wish) with status.

### 8. Rollback Path
- Record backups: `/etc/ssh/sshd_config.crm114.bak.*`, log `dscl` commands executed.
- Generate uninstall script stub that:
  - Restores sshd_config backup.
  - Disables Remote Login if previously off.
  - Removes `crm114` user + home directory (`sudo sysadminctl -deleteUser crm114`).
  - Deletes `/usr/local/libexec/crm114` assets and `~/.ssh` config entry.
  - Kills keep-alive background process.

## Script Structure (Pseudo)
```bash
main() {
  ensure_gum
  show_intro
  require_confirmation || exit 0
  start_sudo_keepalive
  preflight_checks
  create_hidden_user
  configure_remote_login
  setup_local_keys
  install_brew_dependencies
  deploy_wish_binary
  configure_login_shell
  validate_install
  stop_sudo_keepalive
  show_completion
}
```
Each function wraps critical commands in `gum spin` for transparency and returns rich error codes; failures trigger cleanup routines.

## Next Steps
1. Draft actual installer script following this plan, using Gum for UX and idempotent checks.
2. Implement Wish-based binary (or placeholder) that the script can fetch/build.
3. Author uninstall path and documentation sections in README referencing this workflow.
4. Expand research to cover launchd nuances for hidden users if background services become necessary.
