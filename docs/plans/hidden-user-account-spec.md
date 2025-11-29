# Hidden User Account Spec Plan

## Problem / Context
- The installer needs a definitive specification for the `crm114` service account (UID/GID, attributes, permissions, messaging) before provisioning logic can be implemented safely.
- Current documentation in `docs/plans/hidden-user-bootstrap.md` states high-level requirements but lacks a single source of truth describing attribute values, rationale, and operator-facing narratives.
- Without a finalized spec, provisioning, hiding, and idempotence work risk drift, conflicting assumptions, or user confusion.

## Goals
- Choose a UID/GID strategy (reserved static vs. auto-assigned) and document detection/repair logic for collisions.
- Enumerate every required DirectoryService attribute (shell, home path, primary group, IsHidden, AuthenticationAuthority, SecureToken posture, password storage expectations).
- Define filesystem requirements for `/Users/.crm114` (ownership, permissions, creation flow) and how to validate them.
- Script the exact Gum messaging/narration that explains why the account is created, what it does, and how the operator can inspect it safely.
- Produce acceptance criteria that downstream provisioning/hiding tasks can reference unambiguously.

## Non-Goals
- Implementing account creation or removal logic (covered by other tasks).
- Managing runtime automation performed by the `crm114` account.
- Designing launch agents/daemons or secure logging for account usage (future plans).

## Constraints / Assumptions
- Target machines are Apple Silicon macOS with `sysadminctl`, `dscl`, `createhomedir`, `/usr/libexec/PlistBuddy`, and `dsmemberutil` available.
- The hidden account must remain invisible to loginwindow/Fast User Switching and must not own GUI sessions.
- SecureToken should stay disabled to avoid FileVault implications unless future requirements change.
- The spec must be consumable by POSIX sh scripts and automated tests with no external dependencies beyond built-in tools.

## High-Level Approach
1. **UID/GID Policy**: Evaluate static UID (e.g., 550) vs. auto-assigned; define detection rules, collision handling, and documentation language.
2. **Attribute Matrix**: List each DirectoryService key/value pair (home, shell, password policy, AuthenticationAuthority, groups, IsHidden) plus required filesystem state.
3. **Messaging Narrative**: Draft Gum/simple-mode copy explaining preflight checks, creation intent, verification, and safety guidance.
4. **Acceptance Checklist**: Capture verification steps (e.g., `dscl` reads, permission checks) that provisioning/hiding steps must satisfy; integrate into tests later.
5. **Documentation Updates**: Feed finalized decisions into `docs/research/hidden-user-bootstrap.md`, the parent plan, and installer copy references.

## Attribute & Filesystem Specification

### DirectoryService attribute matrix
| Attribute | Required value | Detect & repair |
| --- | --- | --- |
| `RecordName`, `RealName` | `crm114`; `CRM114 Service Account` | `dscl . -read /Users/crm114 RecordName RealName`. Recreate with `dscl . -create /Users/crm114 RecordName crm114` and `... RealName "CRM114 Service Account"` if drifted. |
| `UniqueID` | Let `sysadminctl` auto-assign the next available UID (>=501). Once created, the UID must stay stable. | `UID=$(dscl . -read /Users/crm114 UniqueID | awk '{print $2}')`. Ensure `dscl . -search /Users UniqueID "$UID"` returns only `crm114`; otherwise abort and instruct the operator to remove the conflicting record before reinstalling. |
| `PrimaryGroupID` | Dedicated `crm114` group whose GID matches `UniqueID`. No admin membership. | `dscl . -read /Groups/crm114 PrimaryGroupID` must equal the UID above. Repair via `dscl . -create /Groups/crm114 PrimaryGroupID "$UID"` and `dscl . -append /Groups/crm114 GroupMembership crm114`. Confirm `dsmemberutil checkmembership -U crm114 -G admin` exits non-zero. |
| `UserShell` | `/usr/bin/false` | `dscl . -read /Users/crm114 UserShell`. Reset with `dscl . -create /Users/crm114 UserShell /usr/bin/false`. |
| `NFSHomeDirectory` | `/Users/.crm114` | `dscl . -read /Users/crm114 NFSHomeDirectory`. If wrong, `dscl . -create /Users/crm114 NFSHomeDirectory /Users/.crm114` and rerun `createhomedir -c -u crm114`. |
| `Password`, `ShadowHashData` | `Password "*"` and **no** `ShadowHashData` node to keep the account passwordless. | `dscl . -read /Users/crm114 Password` must equal `*`. `dscl . -read /Users/crm114 ShadowHashData` should return non-zero; if it exists, delete with `dscl . -delete /Users/crm114 ShadowHashData`. |
| `AuthenticationAuthority` | First entry must be `;DisabledUser;`. Additional Apple-managed tokens may follow but must not re-enable login. | `dscl . -read /Users/crm114 AuthenticationAuthority | grep ';DisabledUser;'`. Reapply with `dscl . -create /Users/crm114 AuthenticationAuthority ";DisabledUser;"`. |
| `IsHidden` | `1` | `dscl . -read /Users/crm114 IsHidden`. Repair with `dscl . -create /Users/crm114 IsHidden 1`. |
| `GeneratedUID` | Stable UUID assigned at creation. Needed for ACL references. | `dscl . -read /Users/crm114 GeneratedUID`. Never overwrite; treat changes as corruption and require operator intervention. |
| Secondary groups | No automatic `admin` membership; optional `staff` secondary membership only if POSIX paths demand it. | `dsmemberutil checkmembership -U crm114 -G staff` may be used for diagnostics. Refuse to add any other groups without an explicit future requirement. |

### Filesystem state
| Path | Owner / Group | Mode | Enforcement |
| --- | --- | --- | --- |
| `/Users/.crm114` | `crm114:crm114` | `0700` | Create with `createhomedir -c -u crm114`. Reapply `chown -R crm114:crm114 /Users/.crm114` and `chmod 700 /Users/.crm114` on every run. |
| `/Users/.crm114/.crm114-profile` (sentinel) | `crm114:crm114` | `0600` | Write installer state (e.g., creation timestamp + UID) to this file so drift detection can confirm ownership without inspecting arbitrary payloads. |
| `/Library/Preferences/com.apple.loginwindow.plist` | `root:wheel` | `0644` | Must contain `HiddenUsersList` entry `crm114`. Update via `/usr/libexec/PlistBuddy` while preserving other entries. |
| `/var/db/dslocal/nodes/Default/users/crm114.plist` | `root:wheel` | `0600` | Implicit DirectoryService backing store; touched only by `dscl`/`sysadminctl`. Validate existence indirectly via `dscl . -read`. |

### Loginwindow & hiding signals
- `HiddenUsersList` inside `/Library/Preferences/com.apple.loginwindow.plist` must include `crm114` exactly once. Extraction via `plutil -extract HiddenUsersList raw ...` ensures idempotence before rewriting.
- `IsHidden=1` (see matrix) is mandatory for Ventura/Sonoma where loginwindow may ignore the plist if the flag is unset.
- `Accounts PrefPane` suppression is verified with `dscl . -read /Users/crm114 AuthenticationAuthority` to guarantee `;DisabledUser;` remains the first token.

### Drift detection & repair routine
1. `dscl . -read /Users/crm114` for every key listed above; capture values for logging and comparison.
2. Compare stored sentinel metadata (`/Users/.crm114/.crm114-profile`) against live UID/GID to ensure the filesystem and DirectoryService agree. If they diverge, prefer DirectoryService values and re-`chown` the tree.
3. Inspect `/Library/Preferences/com.apple.loginwindow.plist` for duplicate or missing entries before mutating it; rebuild the array atomically when needed.
4. Abort with actionable messaging if another account holds the expected UID/GID or if `GeneratedUID` changes, since that indicates manual tampering that automation must not auto-fix.

### SecureToken & passwordless posture
- `sysadminctl -secureTokenStatus crm114` must report `DISABLED`. Record the output; failing to do so blocks provisioning.
- Never call `sysadminctl -secureTokenOn` for this account. If the OS auto-enables SecureToken (rare), immediately run `sysadminctl -secureTokenOff crm114 -password - <<<""` before the password is wiped, or instruct the operator to remove and recreate the account.
- Keep the account passwordless by setting `Password "*"`, deleting `ShadowHashData`, and ensuring no `AuthenticationAuthority` entry reintroduces password-backed flows.

### Acceptance sampling commands
- `dscl . -read /Users/crm114 RecordName RealName UniqueID PrimaryGroupID UserShell NFSHomeDirectory AuthenticationAuthority IsHidden` must match the table above.
- `dscl . -read /Groups/crm114 PrimaryGroupID GroupMembership` must show `crm114` as both the owner and only member.
- `stat -f '%Su %Sg %Sp' /Users/.crm114` must print `crm114 crm114 drwx------`.
- `plutil -extract HiddenUsersList raw /Library/Preferences/com.apple.loginwindow.plist | grep 'crm114'` ensures the loginwindow array contains the entry exactly once.
- `sysadminctl -secureTokenStatus crm114` output logged as part of verification; anything other than `SecureToken is DISABLED for user crm114` is a blocker.

## Messaging Narrative

### Story beats
- **Preflight gating** — Tell the operator we are confirming cached sudo credentials and admin membership once, emphasize that passwords never leave the terminal, and hint that hidden-account work cannot continue without that confirmation.
- **Account creation and hardening** — Explain that `crm114` is a helper account with no login window presence, a locked shell, and a hidden home used strictly for automation; highlight that it inherits only the permissions we assign and can be audited any time.
- **Verification** — Describe how we double-check DirectoryService attributes, the hidden home, and loginwindow state before moving on; surface only high-level privacy assurances unless the user opted into debug logs.
- **Wrap-up** — Reassure the operator that nothing changes about their own account, point to the commands they can run to inspect `crm114`, and state how to remove it with the uninstaller if desired.
- **Failure / remediation** — When a drift or collision blocks progress, show copy that names the mismatched attribute (UID, home path, SecureToken, etc.) and explains how to fix it before re-running the installer.

### Gum-mode copy (default UX)
| Stage | Title | Primary copy | Secondary copy |
| --- | --- | --- | --- |
| Preflight | "Confirming your admin powers" | "We ask macOS once to prove you can run sudo so the hidden helper stays under your control." | "Your password never leaves this Mac; we just need a thumbs-up before continuing." |
| Account creation | "Creating the hidden crm114 helper" | "crm114 is a passwordless background account with a hidden home directory." | "It only runs installer-managed automation and stays invisible to the login window." |
| Verification | "Double-checking crm114's footprint" | "We verify its home, hidden status, and DirectoryService fields so nothing drifts." | "If anything looks off we'll pause and show you how to repair it." |
| Wrap-up | "crm114 helper is ready" | "You can inspect it anytime with 'sudo dscl . -read /Users/crm114' or remove it via our uninstaller." | "We log every change so support can audit the run later." |
| Failure / remediation | "crm114 needs attention" | "macOS reported a conflicting UID/home/attribute. Nothing was changed." | "Fix the noted issue (see debug log snippet below) and rerun the installer when ready." |

### Simple-mode copy (`CRM114_SIMPLE_MODE=1`)
- Preflight: print `==> Checking sudo access so we can add the hidden crm114 helper...` and, on success, `✓ Sudo confirmed; continuing with hidden account setup.`
- Account creation: print `==> Creating the hidden crm114 helper (no login window entry, locked shell)...` followed by `✓ crm114 created and passwordless.`
- Verification: print `==> Verifying crm114 attributes, hidden home, and loginwindow entry...` followed by either `✓ crm114 looks good and stays hidden.` or an error prefixed with `!!` plus the attribute that failed.
- Wrap-up: print `==> Hidden helper ready. Inspect anytime with: sudo dscl . -read /Users/crm114` and follow with `Run ./install.sh --remove` (or equivalent) as the removal pointer.

### Debug + SecureToken messaging
- Default copy omits SecureToken references; on success we simply log that crm114 stays hidden. The only times SecureToken is mentioned are when `sysadminctl -secureTokenStatus` returns anything other than `DISABLED` or when the operator passes `--debug`.
- When `--debug` (or `$CRM114_DEBUG=1`) is set, append `[debug] crm114 SecureToken status: <status>` after the verification step so advanced users see the precise output.
- On failure, surface a Gum alert / simple-mode `!!` line saying `crm114 must have SecureToken disabled; macOS reported <status>. Remove conflicting policies and rerun.` This keeps the setting implicit for successful runs yet explicit when remediation is required.

## Milestones / Phases
1. **UID Strategy Finalization** – Document decision, detection flow, and collision handling playbook.
2. **Attribute & Filesystem Spec** – Complete the field matrix + required permissions/ownership notes.
3. **Messaging & Acceptance Criteria** – Write Gum/simple copy, list operator assurances, and define verification bullets.
4. **Plan/Research Integration** – Update related docs to reflect the finalized spec and expose it to implementation tasks.

## Risks / Tradeoffs
- Choosing a static UID could conflict with existing local users; auto-assigned IDs risk inconsistency across machines. Decision must balance predictability with safety.
- Overly prescriptive specs might fail on older macOS builds; need conditional notes where behavior differs.
- Messaging that reveals too much implementation detail could confuse operators; must stay concise while transparent.

## Decisions
- UID/GID: allow macOS to auto-allocate the next available UID/GID, but detect collisions and repair attributes if `crm114` already exists with mismatched values; no statically reserved UID like 550.
- Groups: create a dedicated `crm114` primary group for isolation, but keep secondary membership minimal (e.g., continue relying on `staff` only when required) so the account stays self-contained and doesn’t inherit additional privileges.
- Operator guidance: the installer copy will reassure users that account creation is transparent and audited internally; no manual verification steps are required, and future SSH access (e.g., `ssh crm114@localhost`) will be planned separately.

## Related Research
- `docs/research/hidden-user-bootstrap.md`

## Related Research
- `docs/research/hidden-user-bootstrap.md`

## Checklist
- [x] account-spec-uid-policy — Finalize UID/GID selection, collision detection, and documentation.
- [x] account-spec-attributes — Produce authoritative attribute/filesystem matrix (dscl keys, permissions, SecureToken stance).
- [x] account-spec-messaging — Draft Gum/simple-mode narratives explaining the hidden account to operators.
- [ ] account-spec-docs — Update parent plan + research docs with finalized spec and acceptance criteria.

## Linked Tasks
- `account-spec-uid-policy`
- `account-spec-attributes`
- `account-spec-messaging`
- `account-spec-docs`
