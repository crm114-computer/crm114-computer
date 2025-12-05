#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

run_test() {
    name="$1"
    shift
    printf '== %s ==\n' "$name"
    "$@"
    printf 'ok %s\n' "$name"
}

run_test passes-on-real-host "$SCRIPT_DIR/install/detect_system_test.sh"
run_test rejects-non-darwin "$SCRIPT_DIR/install/detect_system_test.sh"
run_test sudo-eligibility "$SCRIPT_DIR/install/sudo_checks_test.sh"
run_test hidden-user-provisioning "$SCRIPT_DIR/install/provision_hidden_user_test.sh"
