#!/bin/sh
set -eu

MIN_MACOS_VERSION="13.0.0"
CRM114_COLOR_INFO="#8E8E8E"
CRM114_COLOR_SUCCESS="#00D98E"
CRM114_COLOR_WARN="#FFAF00"
CRM114_COLOR_ERROR="#FF5F5F"
CRM114_SIMPLE_MODE="${CRM114_INSTALLER_SIMPLE:-}"
CRM114_WORK_DIR="${CRM114_WORK_DIR:-$HOME/.crm114}"
GUM_AVAILABLE=0
CRM114_SUDO_KEEPALIVE_PID=""
CRM114_SUDO_REFRESH_INTERVAL="${CRM114_SUDO_REFRESH_INTERVAL:-60}"
CRM114_DEBUG=0
if [ -n "${CRM114_INSTALLER_DEBUG:-}" ] && [ "${CRM114_INSTALLER_DEBUG:-}" != "0" ]; then
    CRM114_DEBUG=1
fi
CRM114_CURRENT_STAGE="init"

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
            "$*"
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
        gum log --level "$level" "$*"
    else
        printf '[%s] %s\n' "$level" "$*"
    fi
}

fail() {
    error_box "Error: $1"
    exit 1
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
}

set_stage() {
    CRM114_CURRENT_STAGE="$1"
    debug_msg "Stage -> $CRM114_CURRENT_STAGE"
}

usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Options:
  --debug          Enable verbose diagnostic logging (or set CRM114_INSTALLER_DEBUG=1)
  -h, --help       Show this help message and exit
EOF
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --debug)
                CRM114_DEBUG=1
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


    if sudo -n true 2>/dev/null; then
        debug_msg "sudo -n true succeeded"
        success_msg "Sudo confirmed without prompt."
    else
        debug_msg "sudo -n true failed; invoking sudo -v"
        if sudo -v -B -n >/dev/null 2>&1; then
            debug_msg "sudo -v non-interactive succeeded"
            success_msg "Sudo confirmed without prompt."
        elif sudo -v >/dev/null 2>&1; then
            debug_msg "sudo -v succeeded after prompt"
            success_msg "Sudo confirmed after authentication."
        else
            debug_msg "sudo -v failed"
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

    sudo -n true 2>/dev/null || sudo -v || fail "Unable to refresh sudo credentials."

    (
        while true; do
            sleep "$CRM114_SUDO_REFRESH_INTERVAL"
            if ! sudo -n true >/dev/null 2>&1; then
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

    set_stage "complete"
    log_msg info "Initial checks complete"
}

main "$@"
