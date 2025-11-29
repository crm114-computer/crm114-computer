# Hidden Service User Research

## Questions
- How can the installer prove that the invoking operator can obtain sudo, even when credentials are not cached?
- What UID/GID ranges and attributes keep the `crm114` user hidden from GUI login surfaces while remaining scriptable via `sudo -u`?
- Which commands best provision `crm114` with home `/Users/.crm114` and guarantee the directory’s existence, ownership, and permissions?
- How do we harden the account (shell, AuthenticationAuthority, SecureToken, admin membership) to block GUI or direct logins?
- What idempotence checks confirm whether the account already exists and if its attributes drifted from our spec?
- How can we automate cleanup: deleting directory service records, home directory, and loginwindow entries without harming other users?
- Which verification commands should the installer run (and log) to prove the account is hidden and inaccessible via GUI/standard shells?
- How do we ensure the account remains passwordless, eliminating rotation overhead while keeping the user unusable for interactive logins?

## Findings

### Sudo eligibility & operator validation
```
if sudo -n true 2>/dev/null; then
  sudo_fresh=1
else
  if sudo -v; then sudo_fresh=1; else sudo_fresh=0; fi
fi
```
- `sudo -n true` exits 0 when cached creds exist; otherwise we call `sudo -v` to prompt exactly once. Failure means abort with guidance.
- `dsmemberutil checkmembership -U "$USER" -G admin` (exit 0 == member) produces actionable error strings (“user is a member/not a member”).
- Wrap sudo preflight in `with_spinner` for transparency; log both positive (“Sudo rights confirmed”) and negative outcomes.
- Track prompt timeout using `sudo -v -B` for non-blocking behavior in CI; fallback to interactive when `$CRM114_SIMPLE_MODE` unset.

### Account creation & passwordless hardening
```
RESERVED_UID=550
TEMP_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
sysadminctl -addUser crm114 \
  -UID "$RESERVED_UID" \
  -fullName "CRM114 Service" \
  -home /Users/.crm114 \
  -shell /usr/bin/false \
  -password - <<<"$TEMP_PASSWORD"
```
Attribute requirements:
| Attribute | Value | Purpose |
| --- | --- | --- |
| `UserShell` | `/usr/bin/false` | Prevents login shells even if user is revealed |
| `NFSHomeDirectory` | `/Users/.crm114` | Hidden home path |
| `UniqueID` | `>=500` (recommend 550) | Avoid conflicts with system accounts |
| `PrimaryGroupID` | `20` (`staff`) | Standard macOS non-admin group |
| `AuthenticationAuthority` | `;DisabledUser;` | Denies GUI loginwindow auth and disables password prompts |
| `IsHidden` | `1` | Hides from loginwindow and fast user switching |

Immediately after creation, wipe password material so the account is passwordless:
```
dscl . -create /Users/crm114 Password "*"
dscl . -delete /Users/crm114 ShadowHashData 2>/dev/null || true
dscl . -create /Users/crm114 AuthenticationAuthority ";DisabledUser;"
```
Setting `Password "*"` and removing `ShadowHashData` leaves no hash on disk. Pairing that with `;DisabledUser;` makes the account unusable for GUI or TTY login, so no future rotation is required.

### Home directory creation & permissions
```
createhomedir -c -u crm114 >/dev/null
chown -R crm114:staff /Users/.crm114
chmod 700 /Users/.crm114
```
- Running `createhomedir` ensures macOS populates default dotfiles even though the path is hidden.
- Enforce `0700` permissions after any installer rerun to preserve privacy.

### Hiding from GUI & fast user switching
```
/usr/libexec/PlistBuddy -c "Add :HiddenUsersList:0 string crm114" /Library/Preferences/com.apple.loginwindow 2>/dev/null || true
plutil -extract HiddenUsersList raw /Library/Preferences/com.apple.loginwindow.plist 2>/dev/null |
  python -c 'import json,sys; data=json.load(sys.stdin);\nif "crm114" not in data: data.append("crm114");\nprint(json.dumps(data))' |
  sudo tee /tmp/hidden-users.json >/dev/null &&
/usr/libexec/PlistBuddy -c "Delete :HiddenUsersList" /Library/Preferences/com.apple.loginwindow 2>/dev/null &&
/usr/libexec/PlistBuddy -c "Add :HiddenUsersList array" /Library/Preferences/com.apple.loginwindow &&
python -c 'import json; import sys; import subprocess;\narr=json.load(open("/tmp/hidden-users.json"));\nfor idx,entry in enumerate(arr):
    subprocess.run(["/usr/libexec/PlistBuddy", "-c", f"Add :HiddenUsersList:{idx} string {entry}", "/Library/Preferences/com.apple.loginwindow"])
'
```
- Prefer `PlistBuddy` over `defaults write` to avoid plist reformatting; ensure duplicate entries aren’t added by inspecting the JSON representation first.
- `IsHidden=1` plus membership in `HiddenUsersList` covers Ventura/Sonoma loginwindow; maintain both for compatibility.
- Ensure account lacks SecureToken/admin rights: `sysadminctl -secureTokenStatus crm114` should return “DISABLED”. If not, run `sysadminctl -secureTokenOff crm114 -password - <<<"$TEMP_PASSWORD"` before wiping the password (or confirm SecureToken never enabled when using disabled AuthenticationAuthority).

### Verification & idempotence
```
if dscl . -read /Users/crm114 >/dev/null 2>&1; then
  CURRENT_HOME=$(dscl . -read /Users/crm114 NFSHomeDirectory | awk '{print $2}')
  CURRENT_SHELL=$(dscl . -read /Users/crm114 UserShell | awk '{print $2}')
  CURRENT_HIDDEN=$(dscl . -read /Users/crm114 IsHidden | awk '{print $2}')
  HAS_SHADOW=$(dscl . -read /Users/crm114 ShadowHashData 2>/dev/null || true)
fi
```
- Drift detection: compare `CURRENT_HOME`, `CURRENT_SHELL`, `CURRENT_HIDDEN`, and ensure `ShadowHashData` is absent. Repair mismatches immediately.
- `plutil -extract HiddenUsersList raw ...` returning JSON lets us check for the username without mutation.
- Negative verification: `su - crm114 -c true` must exit non-zero; `launchctl asuser $(id -u crm114) true` should fail because no GUI session exists.
- Log verification results for support: `log_msg info "Hidden user verified (home: $CURRENT_HOME, passwordless=true)"`.

### Cleanup / removal path
```
sudo launchctl bootout gui/$(id -u crm114) 2>/dev/null || true
sudo dscl . -delete /Users/crm114 || true
sudo rm -rf /Users/.crm114 || true
# Remove from HiddenUsersList using filtered JSON rewrite (similar to add path)
```
- Remove username from `HiddenUsersList` via temporary JSON: `plutil -extract HiddenUsersList raw ... | python -c '...'` to rewrite without crm114.
- Deleting the user leaves cached DirectoryService entries; calling `dscacheutil -flushcache` ensures new sessions don’t display stale data.
- Document manual recovery: if deletion fails mid-way, run `dscl . -delete /Users/crm114` again and ensure `/Users/.crm114` removed.

## Options Considered
1. **Pure `dscl` provisioning** – Fine-grained but brittle; difficult to undo on errors.
2. **`sysadminctl` + hardening pass** – Preferred; uses Apple tooling yet allows post-tuning of attributes and hiding flags.
3. **Configuration profiles / MDM payloads** – Requires signing, adds dependencies; unnecessary for local installer.
4. **Installer .pkg with pre-created user template** – Complicates updates and SIP interactions; rejected.

## Decision / Recommendation
- Adopt Option 2 (sysadminctl + hardening) with reserved UID 550 and `staff` group.
- Enforce sudo preflight using the combined `sudo -n true` / `sudo -v` flow plus `dsmemberutil` membership check; abort when the user cannot elevate.
- Automate hiding via `IsHidden=1` and `HiddenUsersList` updates through `PlistBuddy`, ensuring deduplication.
- After provisioning, immediately wipe password artifacts (`Password "*"`, remove `ShadowHashData`, enforce `;DisabledUser;`). The account becomes passwordless, eliminating rotation while preventing any authentication prompts.
- Use `createhomedir -c -u crm114` followed by ownership/permission enforcement; wrap operations with `with_spinner` for Gum transparency.
- Implement verification routines that log attribute values and explicitly test negative login attempts; provide cleanup commands that reverse every change.

## References / Links
- `man sysadminctl`
- `man dscl`
- `man launchctl`
- Apple Platform Deployment: "Manage hidden administrator accounts" (WWDC2022-10056)
- Apple Support HT203998: "How to hide users from the login window"
