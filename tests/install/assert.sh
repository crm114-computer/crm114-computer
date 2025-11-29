#!/bin/sh
set -eu

fail() {
    printf "assertion failed: %s\n" "$1" >&2
    exit 1
}

assert_eq() {
    expected="$1"
    actual="$2"
    msg="${3:-}"
    if [ "$expected" != "$actual" ]; then
        fail "${msg}expected '$expected', got '$actual'"
    fi
}
