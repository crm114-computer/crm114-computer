#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
INSTALLER="$REPO_ROOT/install.sh"
ASSERT="$SCRIPT_DIR/assert.sh"
. "$ASSERT"

TMPDIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

STATE_DIR="$TMPDIR/state"
mkdir -p "$STATE_DIR"
export CRM114_MOCK_STATE="$STATE_DIR"
export CRM114_MOCK_UID="550"

mock_path() {
    dir="$TMPDIR/$1"
    mkdir -p "$dir"
    printf '%s' "$dir"
}

write_script() {
    path="$1"
    shift
    {
        printf '#!/bin/sh\n'
        if [ "$#" -gt 0 ]; then
            printf '%s\n' "$*"
        fi
    } >"$path"
    chmod +x "$path"
}

write_uname_script() {
    path="$1"
    cat <<'EOF' >"$path"
#!/bin/sh
case "$1" in
    -s)
        printf 'Darwin\n'
        ;;
    -m)
        printf 'arm64\n'
        ;;
    *)
        /usr/bin/uname "$@"
        ;;
esac
EOF
    chmod +x "$path"
}

write_sw_vers_script() {
    path="$1"
    cat <<'EOF' >"$path"
#!/bin/sh
printf '13.5\n'
EOF
    chmod +x "$path"
}

write_sysadminctl_script() {
    path="$1"
    cat <<'EOF' >"$path"
#!/bin/sh
set -eu
STATE="$CRM114_MOCK_STATE"
if [ "${1:-}" = "-addUser" ]; then
    shift
    USER="$1"
    mkdir -p "$STATE"
    echo "$USER" >"$STATE/user"
    echo "${CRM114_MOCK_UID:-550}" >"$STATE/uid"
    : >"$STATE/user_exists"
    exit 0
fi
echo "unexpected sysadminctl invocation: $*" >&2
exit 1
EOF
    chmod +x "$path"
}

touch_state() {
    key="$1"
    value="${2:-}"
    STATE="$CRM114_MOCK_STATE"
    mkdir -p "$STATE"
    printf '%s %s\n' "$key" "$value" >>"$STATE/stages"
}

assert_stage_logged() {
    stage="$1"
    STATE="$CRM114_MOCK_STATE"
    if ! grep -Fq "$stage" "$STATE/stages" 2>/dev/null; then
        printf 'missing stage log for %s\n' "$stage" >&2
        cat "$STATE/stages" >&2
        exit 1
    fi
}

write_dscl_script() {
    path="$1"
    cat <<'EOF' >"$path"
#!/bin/sh
set -eu
STATE="$CRM114_MOCK_STATE"
if [ "${1:-}" = "." ]; then
    shift
fi
case "${1:-}" in
    -read)
        shift
        target="$1"
        shift
        key="${1:-}"
        if [ "$target" = "/Users/testcrm" ]; then
            if [ ! -f "$STATE/user_exists" ]; then
                exit 1
            fi
            if [ -n "$key" ]; then
                case "$key" in
                    UniqueID)
                        printf 'UniqueID: %s\n' "$(cat "$STATE/uid")"
                        ;;
                    *)
                        printf '%s\n' "$key: value"
                        ;;
                esac
            else
                printf 'RecordName: testcrm\n'
            fi
            exit 0
        fi
        if [ "$target" = "/Groups/testcrm" ]; then
            if [ -f "$STATE/group_exists" ]; then
                printf 'RecordName: testcrm\n'
                exit 0
            fi
            exit 1
        fi
        exit 1
        ;;
    -create)
        shift
        target="$1"
        shift
        case "$target" in
            /Groups/testcrm)
                : >"$STATE/group_exists"
                ;;
            /Users/testcrm)
                if [ "${1:-}" = "UniqueID" ]; then
                    echo "${2:-}" >"$STATE/uid"
                fi
                : >"$STATE/user_exists"
                ;;
        esac
        exit 0
        ;;
    -delete|-append)
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$path"
}

write_createhomedir_script() {
    path="$1"
    cat <<'EOF' >"$path"
#!/bin/sh
set -eu
if [ "${1:-}" = "-c" ] && [ "${2:-}" = "-u" ]; then
    mkdir -p "$CRM114_HIDDEN_HOME"
    exit 0
fi
exit 0
EOF
    chmod +x "$path"
}

write_noop_script() {
    path="$1"
    cat <<'EOF' >"$path"
#!/bin/sh
exit 0
EOF
    chmod +x "$path"
}

write_install_script() {
    path="$1"
    cat <<'EOF' >"$path"
#!/bin/sh
set -eu
src=""
dst=""
while [ $# -gt 0 ]; do
    case "$1" in
        -m|-o|-g)
            shift 2
            ;;
        *)
            src="$1"
            shift
            dst="$1"
            shift
            break
            ;;
    esac
done
mkdir -p "$(dirname "$dst")"
if [ "$src" = "/dev/null" ]; then
    : >"$dst"
else
    cp "$src" "$dst"
fi
exit 0
EOF
    chmod +x "$path"
}

setup_mock_env() {
    env_dir="$(mock_path env/bin)"
    write_uname_script "$env_dir/uname"
    write_sw_vers_script "$env_dir/sw_vers"
    write_sysadminctl_script "$env_dir/sysadminctl"
    write_dscl_script "$env_dir/dscl"
    write_createhomedir_script "$env_dir/createhomedir"
    write_script "$env_dir/chown" "exit 0"
    write_script "$env_dir/chmod" "exit 0"
    write_install_script "$env_dir/install"
    for tool in gum brew plutil stat defaults dsmemberutil; do
        write_noop_script "$env_dir/$tool"
    done
    printf '%s' "$env_dir"
}

create_wrapper() {
    path="$1"
    cat <<'EOF' >"$path"
#!/bin/sh
set -eu
log="$CRM114_PRIV_LOG"
stage=""
if [ "${1:-}" = "--stage" ]; then
    stage="$2"
    shift 2
fi
case "${1:-}" in
    -n)
        printf 'sudo -n %s\n' "${2:-}" >>"$log"
        exit 0
        ;;
    -v|-B)
        printf 'sudo %s\n' "$1" >>"$log"
        exit 0
        ;;
esac
if [ -n "$stage" ]; then
    printf '%s | %s' "$stage" "${1:-}" >>"$log"
fi
{
    if [ $# -gt 0 ]; then
        printf '%s' "$1"
        shift
    fi
    for arg in "$@"; do
        printf ' %s' "$arg"
    done
    printf '\n'
} >>"$log"
exec "$@"
EOF
    chmod +x "$path"
}

run_installer_capture() {
    env_dir="$1"
    log_file="$TMPDIR/provision.log"
    wrapper="$TMPDIR/priv-wrapper.sh"
    export CRM114_PRIV_LOG="$log_file"
    create_wrapper "$wrapper"
    export CRM114_PLISTBUDDY_PATH="$env_dir/PlistBuddy"
    write_script "$env_dir/PlistBuddy" "exit 0"
    PATH="$env_dir:$PATH" \
        CRM114_INSTALLER_SIMPLE=1 \
        CRM114_PRIVILEGED_WRAPPER="$wrapper" \
        CRM114_SERVICE_USER="testcrm" \
        CRM114_SERVICE_REALNAME="Test CRM" \
        CRM114_HIDDEN_HOME="$TMPDIR/.testcrm" \
        CRM114_HIDDEN_SENTINEL="$TMPDIR/.testcrm/.profile" \
        "$INSTALLER" >"$TMPDIR/provision.out" 2>"$TMPDIR/provision.err" && rc=$? || rc=$?
    printf '%s\n' "$rc" >"$TMPDIR/provision.status"
    printf '%s' "$log_file"
}

assert_logged() {
    log="$1"
    shift
    if ! grep -Fq "$*" "$log"; then
        printf 'missing command: %s\n' "$*" >&2
        cat "$log" >&2
        exit 1
    fi
}

assert_file_exists() {
    path="$1"
    if [ ! -f "$path" ]; then
        printf 'missing file: %s\n' "$path" >&2
        exit 1
    fi
}

main() {
    env_dir="$(setup_mock_env)"
    log_file="$(run_installer_capture "$env_dir")"
    status=$(cat "$TMPDIR/provision.status")
    if [ "$status" != "0" ]; then
        printf 'installer exited %s\n' "$status" >&2
        cat "$TMPDIR/provision.err" >&2
        exit 1
    fi
    assert_logged "$log_file" sysadminctl -addUser testcrm -fullName "Test CRM" -home "$TMPDIR/.testcrm" -shell /usr/bin/false -password -
    assert_logged "$log_file" dscl . -create /Users/testcrm UserShell /usr/bin/false
    assert_logged "$log_file" dscl . -create /Users/testcrm AuthenticationAuthority ';DisabledUser;'
    assert_logged "$log_file" createhomedir -c -u testcrm
    assert_logged "$log_file" install -m 600 -o testcrm -g testcrm /dev/null "$TMPDIR/.testcrm/.profile"
    assert_file_exists "$TMPDIR/.testcrm/.profile"
    echo "ok hidden user provisioning commands captured"
}

main "$@"
