# Hidden User Bootstrap Plan

## Problem / Context
- Upcoming installer features require a dedicated `crm114` service account for privileged automation on macOS.
- The account must remain invisible to loginwindow/fast user switching and live at `/Users/.crm114`, ensuring both the user and home directory stay hidden.
- Current plans (`gum-powered-installer`, `installer-detection`) do not cover privileged account provisioning, sudo validation, or hidden-user lifecycle management.

## Goals
- Provision a hidden, non-loginable macOS user `crm114` with home `/Users/.crm114`, owned `crm114:staff`, permissions `0700`.
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
1. **Preflight Validation**: Check for sudo capability (`sudo -n true || sudo -v`), confirm the caller is in the `admin` group, and gather system facts.
2. **Idempotent Detection**: Use `dscl . -read /Users/crm114` to determine whether the account exists and whether attributes match requirements.
3. **Provisioning Flow**: Create the account via `sysadminctl -addUser crm114 -UID <reserved> -home /Users/.crm114 -shell /usr/bin/false -password <random>`.
4. **Hardening & Hiding**: Apply `IsHidden=1`, add to `HiddenUsersList`, ensure `AuthenticationAuthority` disables GUI logins, lock down `/Users/.crm114` with `chmod 700`.
5. **Verification & Cleanup Hooks**: Re-read account attributes, confirm hidden status, log results, and document removal path (reverse operations, remove home, update HiddenUsersList, delete plist entries).

## Milestones / Phases
1. **Research & Spec Finalization** – Capture mechanics for hidden accounts (completed via `docs/research/hidden-user-bootstrap.md`).
2. **Sudo & Environment Checks** – Implement preflight sudo detection and guard rails in the installer.
3. **Account Provisioning** – Add creation + hardening steps to `install.sh` (or helper scripts) with Gum messaging.
4. **Idempotence & Validation** – Build verification routines, drift repair logic, and optional dry-run/tests under `tests/install/`.
5. **Removal / Recovery** – Document and script clean removal if needed.

## Risks / Tradeoffs
- Sudo prompts may time out in unattended environments; need clear messaging/fallback.
- Misconfigured attributes could expose the account or block shell automation; thorough validation is required.
- Manipulating loginwindow defaults may affect other hidden users; edits must be scoped precisely and reversible.
- Future macOS changes to directory services tooling could break assumptions; monitoring required.
- Reserved UID collisions may occur if another tool uses the same number; detection must verify availability first.

## Open Questions
- What UID/GID should `crm114` use? (Default auto-assigned vs. fixed high UID such as 550.)
- Do we need additional auditing/logging of actions performed as `crm114`?
- Should the installer set `SecureToken` or explicitly avoid it for this account?

## Related Research
- `docs/research/hidden-user-bootstrap.md`

## Checklist
- [x] Sudo/admin eligibility checks with debug visibility (`hidden-user-sudo-checks`, `installer-debug-flag`)
- [ ] Account specification (UID/GID, attributes, Gum narrative) (`hidden-user-account-spec`)
- [ ] Account provisioning & hardening flow in `install.sh` (`hidden-user-provisioning`)
- [ ] GUI hiding and AuthenticationAuthority adjustments (`hidden-user-hiding`)
- [ ] Idempotence + verification tooling (`hidden-user-idempotence`)
- [ ] Removal / uninstaller routines (`hidden-user-removal`)

## Linked Tasks
- `hidden-user-sudo-checks` – Implement sudo eligibility detection, timeout handling, and admin membership validation.
- `hidden-user-account-spec` – Document UID reservation, attribute requirements, and Gum messaging narrative.
- `hidden-user-provisioning` – Implement account creation, password generation, and home directory setup in `install.sh`.
- `hidden-user-hiding` – Apply IsHidden, HiddenUsersList updates, AuthenticationAuthority changes, and verify GUI suppression.
- `hidden-user-idempotence` – Build verification/drift-repair logic and add scripted tests.
- `hidden-user-removal` – Provide uninstaller routines to delete the account, hidden home, and related plist entries.
