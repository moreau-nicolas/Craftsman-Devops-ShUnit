#!/usr/bin/env bash

set -o nounset
# set -o xtrace

# Set magic variables for current file & dir
__dir_tst="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root_tst="$(cd "$(dirname "${__dir_tst}")" && pwd)" # <-- change this as it depends on your app


SCRIPT_PATH="${__root_tst}/install_trainee_environment.sh"

# Mock "gcloud" command
# save command line in gcloud_log file
# this function has behavior depending on the command line.
gcloud() {
  echo "${FUNCNAME[0]} $*" >> gcloud_log
}

tearDown() {
  rm -f gcloud_log
}

test_should_be_successfull() {
  assertTrue "[ 0 -eq 0 ]"
}

test_should_failed_without_parameters() {
  result=$(source "${SCRIPT_PATH}" 2>&1)
  code=$?

  assertEquals 'Wrong usage message' "$(cat tests/expected/usage_message.txt)" "${result}"
  assertEquals "Wrong return code" '1' "${code}"
}

test_get_cluster_credentials_should_be_successful() {
  USER=static_user source "${SCRIPT_PATH}" --source-only
  # workaround: disable 'set -o errexit'
  set +e
  result=$(USER=other_user get_cluster_credentials)
  code=$?

  assertEquals "Wrong return code" '0' "${code}"
  assertEquals 'Wrong gcloud cmd' 'gcloud container clusters get-credentials formation-ci --region europe-west1 --project formation-ci-static_user' "$(cat gcloud_log)"
  assertEquals 'Wrong result' '## Get credentials other_user' "${result}"
}

# Eat all command-line arguments before calling shunit2.
shift $#
# Load shUnit2.
source "$(which shunit2)"
