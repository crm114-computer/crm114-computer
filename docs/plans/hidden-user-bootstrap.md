# Hidden User Bootstrap Plan

## Problem / Context
- Upcoming installer features require a dedicated `crm114` service account for privileged automation on macOS.
- The account must remain invisible to loginwindow/fast user switching and live at `/Users/.crm114`, ensuring both the user and home directory stay hidden.
- Current plans (`gum-powered-installer`, `installer-detection`) do not cover privileged account provisioning, sudo validation, or hidden-user lifecycle management.
- Automated installer tests have been retired; verification now depends on human-operated `./install.sh --debug` runs captured by operators.

## Goals
- Provision a hidden, non-loginable macOS user `crm114` with home `/Users/.crm114`, owned `crm114:crm114`, permissions `0700`.
- Enforce sudo eligibility preflight so the installer only proceeds when the invoking operator can obtain sudo.
- Harden the account: hide from GUI lists, disable GUI logins, set shell to `/usr/bin/false`, eliminate stored passwords, and ensure the hidden home directory stays private.
- Ensure idempotent behavior: detect existing accounts, repair drift, and safely skip when already compliant.
- Provide uninstall/cleanup steps to remove the user, hidden home, and loginwindow references when requested.

## Non-Goals
- Managing launch agents or daemons for the account (handled in later plans).
- Supporting non-macOS platforms.
- Implementing interactive GUI controls; interaction remains terminal-only.

## Constraints / Assumptions
- Installer runs on Apple Silicon macOS with access to `sysadminctl`, `dscl`, `defaults`, `createhomedir`, and `/usr/libexec/PlistBuddy`.
- User executing the installer is (or can authenticate as) an admin capable of sudo.
- Network access may be limited; tooling must rely on built-in macOS utilities.
- Account must never appear on loginwindow or fast user switching UI, and GUI shells remain disabled permanently.

## High-Level Approach
1. **Gum bootstrap instrumentation**: Stage `gum-bootstrap` decides whether to use Gum or simple mode, installs Gum via Homebrew when missing, and emits debug/stage logs before any privileged prompts so future failures are easy to replay.
2. **Preflight & sudo keepalive**: Stage `sudo-preflight` reuses `run_privileged` helpers to attempt `sudo -n true`, fall back to `sudo -v`, and verify admin group membership; immediately afterward stage `sudo-keepalive` launches the background refresher that keeps credentials alive (respecting `CRM114_SUDO_REFRESH_INTERVAL`) and must log the PID so we can stop it deterministically.
3. **System detection**: Stage `system-detection` validates Darwin/arm64 hosts running at least `$MIN_MACOS_VERSION`, surfaces results through Gum/simple-mode messaging, and exports the detected values for downstream provisioning.
4. **Provisioning flow with logged spinners**: Stage `hidden-user-provision` wraps every privileged call (sysadminctl, dscl, createhomedir, install, chmod/chown) with `with_spinner` helpers; each call now shells through `sudo` (or `$CRM114_PRIVILEGED_WRAPPER`) and appends entries to `CRM114_PRIV_LOG` so humans get progress updates and a machine-readable privileged trace.
5. **Hardening & Hiding**: Enforce passwordless state (`Password "*"`, remove `ShadowHashData`), set `AuthenticationAuthority` to `;DisabledUser;`, set `IsHidden=1`, ensure `HiddenUsersList` includes `crm114`, and lock down `/Users/.crm114` plus the sentinel file with `chmod 700/600` ownership `crm114:crm114`.
6. **Verification & Cleanup Hooks**: Compare DirectoryService reads against the attribute matrix, cross-check sentinel metadata for UID/GID drift, log results (including optional `--debug` SecureToken status), and document removal steps that reverse each change.

## Milestones / Phases
1. **Research & Spec Finalization** – Capture mechanics for hidden accounts (completed via `docs/research/hidden-user-bootstrap.md`).
2. **Sudo & Environment Checks** – Implement preflight sudo detection and guard rails in the installer (complete; enforced by `require_sudo` and `start_sudo_keepalive`).
3. **Account Provisioning** – Add creation + hardening steps to `install.sh` (complete; `hidden-user-provision` wraps sysadminctl/dscl/createhomedir with logged spinners and writes the sentinel).
4. **Idempotence & Validation** – Build verification routines and drift repair logic driven by human-provided debug logs (up next).
5. **Removal / Recovery** – Document and script clean removal if needed.

## Risks / Tradeoffs
- Sudo prompts may time out in unattended environments; need clear messaging/fallback.
- Misconfigured attributes could expose the account or block shell automation; thorough validation is required.
- Manipulating loginwindow defaults may affect other hidden users; edits must be scoped precisely and reversible.
- Future macOS changes to directory services tooling could break assumptions; monitoring required.
- Auto-assigned UID/GID values vary per host; drift detection must compare DirectoryService and filesystem metadata to stay consistent.

## Open Questions
- Do we need additional auditing/logging of actions performed as `crm114` beyond installer traces?

## Related Research
- `docs/research/hidden-user-bootstrap.md`

## Checklist
- [x] Sudo/admin eligibility checks with debug visibility (`hidden-user-sudo-checks`, `installer-debug-flag`)
- [x] Gum bootstrap + sudo keepalive instrumentation (stage logging, keepalive PID management)
- [x] Account specification (UID/GID, attributes, Gum narrative) (`hidden-user-account-spec`)
- [x] Account provisioning & hardening flow in `install.sh` (`hidden-user-provisioning`)
- [x] GUI hiding and AuthenticationAuthority adjustments (`hidden-user-hiding`)
- [ ] Idempotence + verification tooling (`hidden-user-idempotence`)
- [ ] Removal / uninstaller routines (`hidden-user-removal`)

## Linked Tasks
- `hidden-user-sudo-checks` – Implement sudo eligibility detection, timeout handling, and admin membership validation.
- `hidden-user-account-spec` – Document auto-assigned UID/GID policy, attribute matrix, Gum/simple-mode messaging, and SecureToken posture.
- `hidden-user-provisioning` – Implement account creation, password generation, and home directory setup in `install.sh`.
- `hidden-user-hiding` – Apply IsHidden, HiddenUsersList updates, AuthenticationAuthority changes, and verify GUI suppression.
- `hidden-user-idempotence` – Build verification/drift-repair logic and add scripted tests.
- `hidden-user-removal` – Provide uninstaller routines to delete the account, hidden home, and related plist entries.
