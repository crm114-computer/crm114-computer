#!/bin/sh
set -eu

MIN_MACOS_VERSION="13.0.0"
CRM114_COLOR_INFO="#8E8E8E"
CRM114_COLOR_SUCCESS="#00D98E"
CRM114_COLOR_WARN="#FFAF00"
CRM114_COLOR_ERROR="#FF5F5F"
CRM114_SIMPLE_MODE="${CRM114_INSTALLER_SIMPLE:-}"
CRM114_WORK_DIR="${CRM114_WORK_DIR:-$HOME/.crm114}"
CRM114_DEBUG_LOG="${CRM114_DEBUG_LOG:-}"
GUM_AVAILABLE=0
CRM114_SUDO_KEEPALIVE_PID=""
CRM114_SUDO_REFRESH_INTERVAL="${CRM114_SUDO_REFRESH_INTERVAL:-60}"
CRM114_DEBUG=0
if [ -n "${CRM114_INSTALLER_DEBUG:-}" ] && [ "${CRM114_INSTALLER_DEBUG:-}" != "0" ]; then
    CRM114_DEBUG=1
fi
CRM114_CURRENT_STAGE="init"
CRM114_SERVICE_USER="${CRM114_SERVICE_USER:-crm114}"
CRM114_SERVICE_REALNAME="${CRM114_SERVICE_REALNAME:-CRM114 Service Account}"
CRM114_HIDDEN_HOME="${CRM114_HIDDEN_HOME:-/Users/.crm114}"
CRM114_HIDDEN_SENTINEL="${CRM114_HIDDEN_SENTINEL:-$CRM114_HIDDEN_HOME/.crm114-profile}"
CRM114_LOGINWINDOW_PLIST="${CRM114_LOGINWINDOW_PLIST:-/Library/Preferences/com.apple.loginwindow.plist}"
CRM114_UNINSTALL_FIRST=0
CRM114_SKIP_PROVISIONING="${CRM114_SKIP_PROVISIONING:-}"
CRM114_PRIVILEGED_WRAPPER="${CRM114_PRIVILEGED_WRAPPER:-}"
CRM114_PRIV_LOG="${CRM114_PRIV_LOG:-}"
CRM114_DEBUG_LOG="${CRM114_DEBUG_LOG:-}"

set_gum_available() {
    debug_msg "Evaluating Gum availability (simple_mode='${CRM114_SIMPLE_MODE:-}')"
    if [ -z "$CRM114_SIMPLE_MODE" ] && [ -t 1 ] && command -v gum >/dev/null 2>&1; then
        GUM_AVAILABLE=1
    else
        GUM_AVAILABLE=0
    fi
    debug_msg "Gum availability set to $GUM_AVAILABLE"
}

use_gum() {
    [ "$GUM_AVAILABLE" -eq 1 ]
}

style_box() {
    color="$1"
    shift
    if use_gum; then
        gum style \
            --border normal \
            --border-foreground "$color" \
            --foreground "$color" \
            --padding "1 2" \
            --margin "1 0" \
            --align left \
            --width 72 \
            "$@"
    else
        printf '%s\n' "$*"
    fi
}

error_box() {
    if use_gum; then
        gum style \
            --border normal \
            --border-foreground "$CRM114_COLOR_ERROR" \
            --foreground "$CRM114_COLOR_ERROR" \
            --padding "1 2" \
            --margin "1 0" \
            --align left \
            --width 72 \
            "$*" >&2
    else
        printf '%s\n' "$*" >&2
    fi
}

status() {
    style_box "$CRM114_COLOR_INFO" "$*"
}

success_msg() {
    style_box "$CRM114_COLOR_SUCCESS" "$*"
}

warn_msg() {
    style_box "$CRM114_COLOR_WARN" "Warning: $*"
}

log_msg() {
    level="$1"
    shift
    if use_gum; then
        gum log --level "$level" -- "$@"
    else
        printf '[%s] %s\n' "$level" "$*"
    fi
}

fail() {
    error_box "Error: $1"
    exit 1
}

run_privileged() {
    if [ -n "$CRM114_PRIVILEGED_WRAPPER" ]; then
        "$CRM114_PRIVILEGED_WRAPPER" "$@"
    else
        sudo "$@"
    fi
}

run_privileged_nonfatal() {
    if [ -n "$CRM114_PRIVILEGED_WRAPPER" ]; then
        "$CRM114_PRIVILEGED_WRAPPER" "$@" && return 0
        return 1
    fi
    if sudo "$@"; then
        return 0
    fi
    return 1
}

debug_enabled() {
    [ "$CRM114_DEBUG" -eq 1 ]
}

debug_msg() {
    if ! debug_enabled; then
        return
    fi
    timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")
    if use_gum; then
        gum log --level debug "[$timestamp] $*" >&2
    else
        printf '[debug %s] %s\n' "$timestamp" "$*" >&2
    fi
    if [ -n "$CRM114_DEBUG_LOG" ]; then
        printf '[%s] %s\n' "$timestamp" "$*" >>"$CRM114_DEBUG_LOG"
    fi
}

set_stage() {
    CRM114_CURRENT_STAGE="$1"
    debug_msg "Stage -> $CRM114_CURRENT_STAGE"
}

usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Options:
  --debug              Enable verbose diagnostic logging (or set CRM114_INSTALLER_DEBUG=1)
  --uninstall-first    Prompt to remove the existing crm114 user, home, and plist entries before provisioning
  -h, --help           Show this help message and exit
EOF
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --debug)
                CRM114_DEBUG=1
                ;;
            --uninstall-first)
                CRM114_UNINSTALL_FIRST=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                fail "Unknown argument: $1"
                ;;
        esac
        shift
    done
}

with_spinner() {
    title="$1"
    shift
    debug_msg "with_spinner '$title' => $*"
    if use_gum; then
        gum spin --spinner dot --title "$title" --show-output -- "$@"
    else
        printf '%s...\n' "$title"
        "$@"
    fi
}

run_privileged_with_spinner_logged() {
    stage="$1"
    shift
    title="$1"
    shift
    cmd="$1"
    shift
    log_entry="$stage | $cmd $*"
    if [ -n "$CRM114_PRIV_LOG" ]; then
        printf '%s
' "$log_entry" >>"$CRM114_PRIV_LOG"
    fi
    if [ -n "$CRM114_PRIVILEGED_WRAPPER" ]; then
        with_spinner "$title" "$CRM114_PRIVILEGED_WRAPPER" "$cmd" "$@"
    else
        with_spinner "$title" sudo "$cmd" "$@"
    fi
}

has_brew() {
    command -v brew >/dev/null 2>&1
}

ensure_gum() {
    debug_msg "Ensuring Gum dependency"
    if command -v gum >/dev/null 2>&1; then
        set_gum_available
        return 0
    fi

    if ! has_brew; then
        fail "Gum is required for the installer interface. Install Homebrew, then run 'brew install gum'."
    fi

    log_msg info "Installing Gum via Homebrew"
    with_spinner "Installing Gum" brew install gum
    set_gum_available
}

version_to_int() {
    input=$1
    major=$(printf '%s' "$input" | cut -d. -f1)
    minor=$(printf '%s' "$input" | cut -d. -f2 2>/dev/null || printf '0')
    patch=$(printf '%s' "$input" | cut -d. -f3 2>/dev/null || printf '0')
    [ -n "$major" ] || major=0
    [ -n "$minor" ] || minor=0
    [ -n "$patch" ] || patch=0
    printf '%s\n' "$major" "$minor" "$patch" | awk 'NR==1{major=$1+0} NR==2{minor=$1+0} NR==3{patch=$1+0} END{printf "%d\n", major*10000 + minor*100 + patch}'
}

require_sudo() {
    debug_msg "Validating sudo access for user $USER"
    log_msg info "Confirming sudo access"


    if run_privileged -n true 2>/dev/null; then
        debug_msg "run_privileged -n true succeeded"
        success_msg "Sudo confirmed without prompt."
    else
        debug_msg "run_privileged -n true failed; invoking run_privileged -v"
        if run_privileged -v -B -n >/dev/null 2>&1; then
            debug_msg "run_privileged -v -B -n succeeded"
            success_msg "Sudo confirmed without prompt."
        elif run_privileged -v >/dev/null 2>&1; then
            debug_msg "run_privileged -v succeeded after prompt"
            success_msg "Sudo confirmed after authentication."
        else
            debug_msg "run_privileged sudo escalation failed"
            fail "Unable to obtain sudo; ensure you can run sudo before continuing."
        fi
    fi

    if ! dsmemberutil checkmembership -U "$USER" -G admin >/dev/null 2>&1; then
        debug_msg "User $USER is not an admin"
        fail "Current user must be in the admin group to continue."
    fi
    debug_msg "User $USER is an admin"
}

start_sudo_keepalive() {
    debug_msg "Starting sudo keepalive (interval ${CRM114_SUDO_REFRESH_INTERVAL}s)"
    if [ -n "$CRM114_SUDO_KEEPALIVE_PID" ] && kill -0 "$CRM114_SUDO_KEEPALIVE_PID" 2>/dev/null; then
        debug_msg "Sudo keepalive already running (pid $CRM114_SUDO_KEEPALIVE_PID)"
        return
    fi

    run_privileged -n true 2>/dev/null || run_privileged -v || fail "Unable to refresh sudo credentials."

    (
        while true; do
            sleep "$CRM114_SUDO_REFRESH_INTERVAL"
            if ! run_privileged -n true >/dev/null 2>&1; then
                debug_msg "Sudo keepalive detected expired credentials"
                break
            fi
        done
        error_box "Sudo session expired; re-run the installer."
        exit 1
    ) &

    CRM114_SUDO_KEEPALIVE_PID=$!
    debug_msg "Sudo keepalive PID $CRM114_SUDO_KEEPALIVE_PID"
    export CRM114_SUDO_KEEPALIVE_PID
}

stop_sudo_keepalive() {
    if [ -n "$CRM114_SUDO_KEEPALIVE_PID" ] && kill -0 "$CRM114_SUDO_KEEPALIVE_PID" 2>/dev/null; then
        debug_msg "Stopping sudo keepalive (pid $CRM114_SUDO_KEEPALIVE_PID)"
        kill "$CRM114_SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
    fi
}

crm114_on_exit() {
    status="$1"
    stop_sudo_keepalive
    if [ "$status" -ne 0 ]; then
        debug_msg "Installer exiting with status $status (stage=${CRM114_CURRENT_STAGE:-unknown})"
    else
        debug_msg "Installer completed successfully"
    fi
}

crm114_on_signal() {
    signal="$1"
    debug_msg "Received signal $signal at stage ${CRM114_CURRENT_STAGE:-unknown}"
    stop_sudo_keepalive
    exit 1
}

detect_system() {
    debug_msg "Detecting system information"
    log_msg info "Verifying macOS release and architecture"

    CRM114_OS=$(uname -s 2>/dev/null || true)
    debug_msg "uname -s => ${CRM114_OS:-\"\"}"
    [ -n "$CRM114_OS" ] || fail "Unable to determine operating system"
    if [ "$CRM114_OS" != "Darwin" ]; then
        fail "This installer only supports macOS on Apple Silicon"
    fi

    CRM114_ARCH=$(uname -m 2>/dev/null || true)
    debug_msg "uname -m => ${CRM114_ARCH:-\"\"}"
    [ -n "$CRM114_ARCH" ] || fail "Unable to determine CPU architecture"
    if [ "$CRM114_ARCH" != "arm64" ]; then
        fail "This installer requires Apple Silicon (arm64); detected $CRM114_ARCH"
    fi

    CRM114_MACOS_VERSION=$(sw_vers -productVersion 2>/dev/null || true)
    debug_msg "sw_vers => ${CRM114_MACOS_VERSION:-\"\"}"
    [ -n "$CRM114_MACOS_VERSION" ] || fail "Unable to read macOS version"

    detected_version=$(version_to_int "$CRM114_MACOS_VERSION")
    minimum_version=$(version_to_int "$MIN_MACOS_VERSION")
    debug_msg "Version ints: detected=$detected_version minimum=$minimum_version"
    if [ "$detected_version" -lt "$minimum_version" ]; then
        fail "Minimum supported macOS version is $MIN_MACOS_VERSION; detected $CRM114_MACOS_VERSION"
    fi

    export CRM114_OS CRM114_ARCH CRM114_MACOS_VERSION
    success_msg "Environment verified: macOS $CRM114_MACOS_VERSION ($CRM114_ARCH)."
}

ensure_privileged_tools() {
    if command -v ensure_privileged_tools >/dev/null 2>&1 && [ "$(command -v ensure_privileged_tools)" = "$0" ]; then
        return 0
    fi
    required_tools="sysadminctl dscl createhomedir chown chmod install plutil /usr/libexec/PlistBuddy stat defaults"
    missing=0
    for tool in $required_tools; do
        case "$tool" in
            /usr/libexec/PlistBuddy)
                plistbuddy_path="${CRM114_PLISTBUDDY_PATH:-/usr/libexec/PlistBuddy}"
                if [ ! -x "$plistbuddy_path" ]; then
                    log_msg error "Missing PlistBuddy at $plistbuddy_path"
                    missing=1
                fi
                ;;
            *)
                if ! command -v "$tool" >/dev/null 2>&1; then
                    log_msg error "Missing required tool: $tool"
                    missing=1
                fi
                ;;
        esac
    done
    [ "$missing" -eq 0 ] || fail "Missing required macOS tools"
}

current_timestamp() {
    date +"%Y-%m-%dT%H:%M:%S%z"
}

read_dscl_value() {
    key="$1"
    run_privileged dscl . -read "/Users/$CRM114_SERVICE_USER" "$key" 2>/dev/null | awk 'NR>1{printf "%s", $0; next} {print $2}'
}

user_exists() {
    run_privileged dscl . -read "/Users/$CRM114_SERVICE_USER" >/dev/null 2>&1
}

ensure_hidden_home_directory() {
    run_privileged_with_spinner_logged "hidden-user-provision" "createhomedir" createhomedir -c -u "$CRM114_SERVICE_USER" >/dev/null
    run_privileged_with_spinner_logged "hidden-user-provision" "chown hidden home" chown -R "$CRM114_SERVICE_USER:$CRM114_SERVICE_USER" "$CRM114_HIDDEN_HOME"
    run_privileged_with_spinner_logged "hidden-user-provision" "chmod hidden home" chmod 700 "$CRM114_HIDDEN_HOME"
    if [ ! -d "$CRM114_HIDDEN_HOME" ]; then
        fail "Hidden home $CRM114_HIDDEN_HOME missing after createhomedir"
    fi
}

write_hidden_profile_sentinel() {
    metadata="created=$(current_timestamp)"
    tmpfile=$(mktemp)
    printf '%s\n' "$metadata" >"$tmpfile"
    run_privileged_with_spinner_logged "hidden-user-provision" "Install sentinel" install -m 600 -o "$CRM114_SERVICE_USER" -g "$CRM114_SERVICE_USER" "$tmpfile" "$CRM114_HIDDEN_SENTINEL"
    rm -f "$tmpfile"
}

ensure_auth_hiding_attributes() {
    run_privileged_with_spinner_logged "hidden-user-hiding" "Disable auth" dscl . -create "/Users/$CRM114_SERVICE_USER" AuthenticationAuthority ";DisabledUser;"
    run_privileged_with_spinner_logged "hidden-user-hiding" "Apply IsHidden" dscl . -create "/Users/$CRM114_SERVICE_USER" IsHidden 1
}

read_loginwindow_hidden_users() {
    run_privileged python3 - "$CRM114_LOGINWINDOW_PLIST" <<'PY'
import plistlib
import sys
from pathlib import Path
plist_path = Path(sys.argv[1])
try:
    with plist_path.open("rb") as handle:
        data = plistlib.load(handle)
except Exception:
    data = {}
entries = []
for entry in data.get("HiddenUsersList") or []:
    if isinstance(entry, str):
        val = entry.strip()
        if val:
            entries.append(val)
print("\n".join(entries))
PY
}

ensure_hidden_user_loginwindow_entry() {
    run_privileged_with_spinner_logged "hidden-user-hiding" "Ensure HiddenUsersList" python3 - "$CRM114_LOGINWINDOW_PLIST" "$CRM114_SERVICE_USER" <<'PY'
import plistlib
import sys
from pathlib import Path
plist_path = Path(sys.argv[1])
user = sys.argv[2]
try:
    with plist_path.open("rb") as handle:
        data = plistlib.load(handle)
except Exception:
    data = {}
entries = []
for entry in data.get("HiddenUsersList") or []:
    if isinstance(entry, str):
        val = entry.strip()
        if val and val not in entries:
            entries.append(val)
if user not in entries:
    entries.append(user)
data["HiddenUsersList"] = entries
plist_path.parent.mkdir(parents=True, exist_ok=True)
with plist_path.open("wb") as handle:
    plistlib.dump(data, handle)
PY
}

loginwindow_hidden_list_contains_user() {
    hidden_users=$(read_loginwindow_hidden_users 2>/dev/null || true)
    if printf '%s\n' "$hidden_users" | grep -Fx "$CRM114_SERVICE_USER" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

remove_hidden_user_from_loginwindow() {
    run_privileged_with_spinner_logged "hidden-user-uninstall" "Prune HiddenUsersList" python3 - "$CRM114_LOGINWINDOW_PLIST" "$CRM114_SERVICE_USER" <<'PY'
import plistlib
import sys
from pathlib import Path
plist_path = Path(sys.argv[1])
user = sys.argv[2]
try:
    with plist_path.open("rb") as handle:
        data = plistlib.load(handle)
except Exception:
    data = {}
entries = []
for entry in data.get("HiddenUsersList") or []:
    if isinstance(entry, str):
        val = entry.strip()
        if val and val != user and val not in entries:
            entries.append(val)
data["HiddenUsersList"] = entries
plist_path.parent.mkdir(parents=True, exist_ok=True)
with plist_path.open("wb") as handle:
    plistlib.dump(data, handle)
PY
}


verify_hidden_user_state() {
    auth_value=$(read_dscl_value AuthenticationAuthority)
    if [ "$auth_value" != ";DisabledUser;" ]; then
        warn_msg "AuthenticationAuthority drift detected for $CRM114_SERVICE_USER (value='$auth_value')"
    fi

    hidden_value=$(read_dscl_value IsHidden)
    if [ "$hidden_value" != "1" ]; then
        warn_msg "IsHidden attribute drift detected for $CRM114_SERVICE_USER (value='$hidden_value')"
    fi

    if loginwindow_hidden_list_contains_user; then
        debug_msg "HiddenUsersList includes $CRM114_SERVICE_USER"
    else
        warn_msg "HiddenUsersList missing $CRM114_SERVICE_USER; GUI hiding may fail"
    fi
}

prompt_uninstall_hidden_user() {
    if [ "$CRM114_UNINSTALL_FIRST" -ne 1 ]; then
        return
    fi

    if ! user_exists; then
        warn_msg "--uninstall-first requested but user $CRM114_SERVICE_USER is missing; continuing"
        return
    fi

    log_msg warn "--uninstall-first will delete $CRM114_SERVICE_USER and recreate the account."

    style_box "$CRM114_COLOR_WARN" "--uninstall-first requested. This will delete $CRM114_SERVICE_USER, $CRM114_HIDDEN_HOME, and related loginwindow entries before provisioning."

    if use_gum; then
        if ! gum confirm "Remove existing $CRM114_SERVICE_USER before continuing?"; then
            fail "Uninstall aborted at operator request"
        fi
    else
        printf 'Type DELETE to confirm removal of %s: ' "$CRM114_SERVICE_USER"
        read -r confirmation || fail "Unable to read confirmation"
        if [ "$confirmation" != "DELETE" ]; then
            fail "Uninstall aborted"
        fi
    fi

    run_privileged_with_spinner_logged "hidden-user-uninstall" "Remove user" dscl . -delete "/Users/$CRM114_SERVICE_USER" 2>/dev/null || true
    run_privileged_with_spinner_logged "hidden-user-uninstall" "Remove group" dscl . -delete "/Groups/$CRM114_SERVICE_USER" 2>/dev/null || true
    run_privileged_with_spinner_logged "hidden-user-uninstall" "Remove home" rm -rf "$CRM114_HIDDEN_HOME"
    remove_hidden_user_from_loginwindow

    log_msg info "Existing hidden user removed"
}

provision_crm114_user() {
    if [ -n "$CRM114_SKIP_PROVISIONING" ]; then
        log_msg warn "Skipping hidden user provisioning per CRM114_SKIP_PROVISIONING"
        return
    fi

    ensure_privileged_tools
    prompt_uninstall_hidden_user

    if user_exists; then
        log_msg info "Hidden user $CRM114_SERVICE_USER already exists; ensuring attributes"
    else
        temp_password="crm114-$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"
        run_privileged_with_spinner_logged "hidden-user-provision" "Creating hidden user" sysadminctl \
            -addUser "$CRM114_SERVICE_USER" \
            -fullName "$CRM114_SERVICE_REALNAME" \
            -home "$CRM114_HIDDEN_HOME" \
            -shell /usr/bin/false \
            -password - <<EOF
$temp_password
EOF
    fi

    uid=$(read_dscl_value UniqueID)
    [ -n "$uid" ] || fail "Failed to read UID for $CRM114_SERVICE_USER"

    run_privileged_with_spinner_logged "hidden-user-provision" "Ensure crm114 group" dscl . -create "/Groups/$CRM114_SERVICE_USER"
    run_privileged_with_spinner_logged "hidden-user-provision" "Align group GID" dscl . -create "/Groups/$CRM114_SERVICE_USER" PrimaryGroupID "$uid"
    run_privileged_with_spinner_logged "hidden-user-provision" "Lock group password" dscl . -create "/Groups/$CRM114_SERVICE_USER" Password "*"
    run_privileged_with_spinner_logged "hidden-user-provision" "Set group record" dscl . -create "/Groups/$CRM114_SERVICE_USER" RecordName "$CRM114_SERVICE_USER"
    run_privileged_with_spinner_logged "hidden-user-provision" "Ensure group membership" dscl . -append "/Groups/$CRM114_SERVICE_USER" GroupMembership "$CRM114_SERVICE_USER"
    run_privileged_with_spinner_logged "hidden-user-provision" "Assign primary GID" dscl . -create "/Users/$CRM114_SERVICE_USER" PrimaryGroupID "$uid"

    run_privileged_with_spinner_logged "hidden-user-provision" "Set DirectoryService names" dscl . -create "/Users/$CRM114_SERVICE_USER" RecordName "$CRM114_SERVICE_USER"
    run_privileged_with_spinner_logged "hidden-user-provision" "Set real name" dscl . -create "/Users/$CRM114_SERVICE_USER" RealName "$CRM114_SERVICE_REALNAME"
    run_privileged_with_spinner_logged "hidden-user-provision" "Lock shell" dscl . -create "/Users/$CRM114_SERVICE_USER" UserShell /usr/bin/false
    run_privileged_with_spinner_logged "hidden-user-provision" "Set hidden home" dscl . -create "/Users/$CRM114_SERVICE_USER" NFSHomeDirectory "$CRM114_HIDDEN_HOME"
    run_privileged_with_spinner_logged "hidden-user-provision" "Set password star" dscl . -create "/Users/$CRM114_SERVICE_USER" Password "*"
    run_privileged_with_spinner_logged "hidden-user-provision" "Remove hash" dscl . -delete "/Users/$CRM114_SERVICE_USER" ShadowHashData 2>/dev/null || true

    ensure_hidden_home_directory
    ensure_auth_hiding_attributes
    ensure_hidden_user_loginwindow_entry
    write_hidden_profile_sentinel
    verify_hidden_user_state

    log_msg info "Hidden user $CRM114_SERVICE_USER provisioned"
}

main() {
    set_stage "argument-parse"
    parse_args "$@"

    if debug_enabled; then
        debug_msg "Debug mode enabled (pid $$, simple_mode='${CRM114_SIMPLE_MODE:-}')"
    fi

    set_stage "gum-bootstrap"
    set_gum_available
    ensure_gum

    log_msg info "crm114 installer: starting"
    trap 'crm114_on_exit $?' EXIT
    trap 'crm114_on_signal INT' INT
    trap 'crm114_on_signal TERM' TERM

    set_stage "sudo-preflight"
    require_sudo

    set_stage "sudo-keepalive"
    start_sudo_keepalive

    set_stage "system-detection"
    detect_system

    set_stage "hidden-user-provision"
    provision_crm114_user

    set_stage "complete"
    log_msg info "Hidden user provisioning complete"
}

main "$@"
