# CRM114 Installer Reality Check

## Executive Summary
The current `install.sh` script only provisions a hidden macOS user and rewrites `sshd_config`, stopping well before the workflows promised in the research plan and README. It overwrites system SSH configuration, leaves the hidden user’s home owned by `root`, never installs Charm stack dependencies, and provides no Wish binary or validation. Users who run the script end up with a broken SSH daemon configuration and a hidden account that cannot log into its own home directory, yet none of the advertised workstation features exist.

## Methodology
1. Reviewed baseline requirements in `docs/research/crm114-install-script-plan.md`.
2. Audited `install.sh` (session branch `session-1763940000-installer-hidden-user`).
3. Compared expected vs. actual behaviors, capturing file:line references.
4. Evaluated risk/impact for each gap.

## Requirement Gaps
| Area | Plan Expectation | Actual Behavior | Impact |
| --- | --- | --- | --- |
| Telemetry opt-in & consent (plan §0, lines 28-32) | Intro banner plus telemetry/consent capture via Gum | `show_intro_banner`/`require_confirmation` only gate execution; no telemetry choice (install.sh:384-413) | Documentation promises consent flow that doesn’t exist; script misrepresents privacy posture |
| Hidden home ownership (plan §2, lines 38-49) | Hidden home owned by `crm114` for configs, Wish assets | Current script runs `ensure_hidden_home_permissions` so `/Users/.crm114` ends up owned by `crm114:staff` (install.sh:199-221, 393-399); earlier versions left it `root:wheel` | ✅ Fixed – crm114 can now write dotfiles; keep monitoring perms if reinstall cleanup fails |
| Public share cleanup (plan §2, line 49) | Remove `crm114's Public Folder` share point | No share cleanup | Hidden user might appear in Finder/SMB browser |
| Remote Login restriction (plan §3, lines 52-54) | Limit SSH access strictly to `crm114` | Script only adds crm114 to `com.apple.access_ssh` (install.sh:286-294) | Other existing members retain SSH access, contradicting README “hidden-only” claim |
| sshd_config handling (plan §3, lines 55-68) | Backup then surgically adjust config | Script writes a hard-coded heredoc, nuking existing config (install.sh:315-338) | Prior ListenAddress/Port/match rules lost; may break legitimate workflows |
| Local SSH client setup (plan §4, lines 71-80) | Generate dedicated key, add ~/.ssh/config host entry | Script generates key but never writes config or host alias (install.sh:250-269) | Users lack `ssh crm114@localhost` convenience and fingerprint guidance |
| Homebrew dependency install (plan §5, lines 86-95) | Ensure Brew, install Wish/Gum/Go for crm114 | Script only records Brew presence (install.sh:122-134, 421-428) | No Wish binary, Gum not installed persistently, dependencies missing |
| Wish binary + ForceCommand (plan §5-6, lines 92-109) | Install Wish app, set ForceCommand to Wish login shell, register shell | Script creates placeholder zsh launcher (install.sh:302-313) and ForceCommand points to it, but crm114’s `UserShell` stays `/bin/zsh`; `/etc/shells` not updated | `ssh crm114@localhost` drops into zsh instead of Wish TUI; README promise false |
| Validation & rollback (plan §7-8, lines 111-128) | Run ssh tests, provide uninstall script | Script merely logs “Next steps” (install.sh:463-465); no validation or uninstall | Failures go unnoticed; users stranded after config changes |

## Risk Analysis
1. **SSH Service Breakage** – Overwriting `/etc/ssh/sshd_config` removes host-wide directives (ports, Match blocks, host keys). Any syntax mistake locks out all SSH access until manually restored. While a timestamped backup exists, no instructions or automation restores it.
2. **Unusable Hidden User** – Home directory remains root-owned, so future Wish binaries or config writers cannot persist data. ForceCommand sessions would exit immediately when they attempt to write `$HOME`. This contradicts README claims and makes subsequent automation impossible without manual fixes.
3. **Security Regression** – Enabling Remote Login while failing to remove other SSH group members broadens the attack surface (remote users already in `com.apple.access_ssh` retain access). Combined with the script’s `PasswordAuthentication no`, legitimate admins might lose password fallback while their accounts remain SSH-accessible via existing keys.
4. **Expectation Mismatch** – README states the installer “fetches Gum… installs Charm stack binaries and Wish login shell.” None of these occur, so running the script leaves the system half-configured and misleads users into thinking they have a working fantasy workstation.
5. **Lack of Validation/Rollback** – No automated sshd syntax test beyond `sshd -t` (which uses the overwritten file), no connection tests, and no uninstall path. Users cannot recover without manual terminal work even though the README promises backups/uninstall support.

## Recommendations
1. **Align script with plan** – Implement remaining phases: Brew install, Wish binary deployment, ForceCommand shell registration, local SSH config, validation, uninstall tooling.
2. **Fix ownership and sshd editing** – Ensure `/Users/.crm114` is owned by `crm114`; edit sshd_config incrementally (e.g., `Match User` block appended) or use `Include` file to avoid destroying existing config.
3. **Restrict Remote Login properly** – Remove unintended members from `com.apple.access_ssh` or configure `AllowUsers crm114@localhost`.
4. **Update README until script catches up** – Clarify current installer limitations or remove claims until functionality exists.
5. **Document rollback** – Provide uninstall steps and auto-restore backup on failure to prevent lockouts.

## References
- `docs/research/crm114-install-script-plan.md`
- `install.sh` (current branch `session-1763940000-installer-hidden-user`)
- `README.md` installer section
