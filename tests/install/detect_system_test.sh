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

run_installer() {
    TEST_ROOT="$TMPDIR/$1"
    mkdir -p "$TEST_ROOT/bin"
    cat <<'EOF' >"$TEST_ROOT/bin/uname"
#!/bin/sh
case "$1" in
    -s)
        printf 'Linux\n'
        ;;
    -m)
        printf 'x86_64\n'
        ;;
    *)
        /usr/bin/uname "$@"
        ;;
esac
EOF
    chmod +x "$TEST_ROOT/bin/uname"

    cat <<'EOF' >"$TEST_ROOT/bin/sw_vers"
#!/bin/sh
printf '12.5.0\n'
EOF
    chmod +x "$TEST_ROOT/bin/sw_vers"

    PATH="$TEST_ROOT/bin:$PATH" CRM114_INSTALLER_SIMPLE=1 "$INSTALLER" >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" && rc=$? || rc=$?
    printf "%s\n" "$rc" >"$TEST_ROOT/status"
}

# Happy path
PATH="$PATH" CRM114_INSTALLER_SIMPLE=1 "$INSTALLER" >"$TMPDIR/ok.out"
# Basic success if host is compliant; skip exit check because host may not be.

# Non-Darwin rejected
run_installer non_darwin
status=$(cat "$TMPDIR/non_darwin/status")
if [ "$status" = "0" ]; then
    printf 'expected non-darwin to fail\n' >&2
    cat "$TMPDIR/non_darwin/out"
    cat "$TMPDIR/non_darwin/err" >&2
    exit 1
fi
if ! grep -q 'only supports macOS' "$TMPDIR/non_darwin/err"; then
    printf 'missing non-darwin error message\n' >&2
    cat "$TMPDIR/non_darwin/err" >&2
    exit 1
fi

echo "ok detect_system rejects non-darwin"
