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
        # shellcheck disable=SC2124
        if [ "$#" -gt 0 ]; then
            printf '%s\n' "$*"
        fi
    } >"$path"
    chmod +x "$path"
}

write_fake_uname() {
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

write_fake_sw_vers() {
    path="$1"
    cat <<'EOF' >"$path"
#!/bin/sh
printf '13.5\n'
EOF
    chmod +x "$path"
}

setup_env_dir() {
    name="$1"
    dir="$(mock_path "$name")"
    write_script "$dir/gum" "exit 0"
    write_script "$dir/brew" "exit 0"
    write_fake_uname "$dir/uname"
    write_fake_sw_vers "$dir/sw_vers"
    printf '%s' "$dir"
}

run_installer_with_path() {
    name="$1"
    path="$2"
    ( PATH="$path":$PATH CRM114_INSTALLER_SIMPLE=1 "$INSTALLER" >"$TMPDIR/$name.out" 2>"$TMPDIR/$name.err" && rc=$? || rc=$?; printf '%s' "$rc" >"$TMPDIR/$name.status" )
}

run_installer_debug() {
    name="$1"
    path="$2"
    ( PATH="$path":$PATH CRM114_INSTALLER_SIMPLE=1 "$INSTALLER" --debug >"$TMPDIR/$name.out" 2>"$TMPDIR/$name.err" && rc=$? || rc=$?; printf '%s' "$rc" >"$TMPDIR/$name.status" )
}


# scenario 1: sudo -n true succeeds immediately
path1="$(setup_env_dir sudo_n_success)"
cat <<'EOF' >"$TMPDIR/sudo_n_true"
#!/bin/sh
if [ "$1" = "-n" ]; then
    exit 0
fi
exec /usr/bin/sudo "$@"
EOF
chmod +x "$TMPDIR/sudo_n_true"
PATH_OVR="$TMPDIR/sudo_n_true:$path1"
run_installer_with_path sudo_n_success "$PATH_OVR"
assert_eq 0 "$(cat "$TMPDIR/sudo_n_success.status")" "sudo -n true path should succeed"
if ! grep -q 'Initial checks complete' "$TMPDIR/sudo_n_success.out"; then
    printf 'missing success log for sudo -n scenario\n' >&2
    exit 1
fi

# debug flag should produce debug output
run_installer_debug sudo_n_debug "$PATH_OVR"
assert_eq 0 "$(cat "$TMPDIR/sudo_n_debug.status")" "sudo -n debug run should succeed"
if ! grep -q '\\[debug' "$TMPDIR/sudo_n_debug.err"; then
    printf 'expected debug output in debug mode\n' >&2
    cat "$TMPDIR/sudo_n_debug.err" >&2
    exit 1
fi

# scenario 2: sudo -n fails but sudo -v succeeds
path2="$(setup_env_dir sudo_v_success)"
cat <<'EOF' >"$TMPDIR/sudo_v"
#!/bin/sh
if [ "$1" = "-n" ]; then
    exit 1
fi
if [ "$1" = "-B" ]; then
    # simulate non-interactive sudo -v -B -n failure
    exit 1
fi
if [ "$1" = "-v" ]; then
    exit 0
fi
exit 1
EOF
chmod +x "$TMPDIR/sudo_v"
PATH_OVR="$TMPDIR/sudo_v:$path2"
run_installer_with_path sudo_v_success "$PATH_OVR"
assert_eq 0 "$(cat "$TMPDIR/sudo_v_success.status")" "sudo -v fallback should succeed"
if ! grep -q 'Initial checks complete' "$TMPDIR/sudo_v_success.out"; then
    printf 'missing success log for sudo -v scenario\n' >&2
    exit 1
fi

# scenario 3: sudo -n and sudo -v both fail
path3="$(setup_env_dir sudo_fail)"
write_script "$path3/sudo" "exit 1"
run_installer_with_path sudo_fail "$path3"
if [ "$(cat "$TMPDIR/sudo_fail.status")" = "0" ]; then
    printf 'expected sudo failure path to exit non-zero\n' >&2
    cat "$TMPDIR/sudo_fail.err" >&2
    exit 1
fi
if ! grep -q 'Unable to obtain sudo; ensure you can run sudo' "$TMPDIR/sudo_fail.err"; then
    printf 'missing sudo failure message\n' >&2
    cat "$TMPDIR/sudo_fail.err" >&2
    exit 1
fi

# scenario 4: admin membership check fails
path4="$(setup_env_dir admin_fail)"
cat <<'EOF' >"$TMPDIR/sudo_admin"
#!/bin/sh
if [ "$1" = "-n" ]; then
    exit 0
fi
exec /usr/bin/sudo "$@"
EOF
chmod +x "$TMPDIR/sudo_admin"
write_script "$path4/dsmemberutil" "exit 1"
PATH_OVR="$TMPDIR/sudo_admin:$path4"
run_installer_with_path admin_fail "$PATH_OVR"
if [ "$(cat "$TMPDIR/admin_fail.status")" = "0" ]; then
    printf 'expected admin membership failure to exit non-zero\n' >&2
    exit 1
fi
if ! grep -q 'Current user must be in the admin group' "$TMPDIR/admin_fail.err"; then
    printf 'missing admin failure message\n' >&2
    cat "$TMPDIR/admin_fail.err" >&2
    exit 1
fi

echo "ok sudo eligibility scenarios"
