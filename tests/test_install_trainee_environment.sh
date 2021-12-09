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

test_should_failed_without_parameters() {
  result=$(source "${SCRIPT_PATH}" --source-only 2>&1)
  code=$?

  printf "${result}"
  assertEquals "Wrong return code" '0' "${code}"
}

# Eat all command-line arguments before calling shunit2.
shift $#
# Load shUnit2.
source "$(which shunit2)"
