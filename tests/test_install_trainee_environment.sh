#!/usr/bin/env bash

set -o nounset
# set -o xtrace

# Set magic variables for current file & dir
__dir_tst="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root_tst="$(cd "$(dirname "${__dir_tst}")" && pwd)" # <-- change this as it depends on your app


SCRIPT_PATH="${__root_tst}/install_trainee_environment.sh"

test_should_be_successfull() {
  assertTrue "[ 0 -eq 0 ]"
}

# Eat all command-line arguments before calling shunit2.
shift $#
# Load shUnit2.
source "$(which shunit2)"
