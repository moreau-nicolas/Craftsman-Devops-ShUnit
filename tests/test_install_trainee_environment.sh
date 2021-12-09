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

  case "$*" in
    'organizations list --filter=DISPLAY_NAME=zenika.com --format=value(ID)')
      printf "10000000000"
      return 0
      ;;
    'alpha billing accounts list --filter=NAME:Facturation Zenika --format=value(ACCOUNT_ID)')
      printf "AAAAAA-BBBBBB-CCCCCC"
      return 0
      ;;
    *)
      return 0
      ;;
  esac
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

test_create_cluster_should_be_successful() {
  USER=static_user source "${SCRIPT_PATH}" --source-only
  # workaround: disable 'set -o errexit'
  set +e
  result=$(create_cluster)
  code=$?

  assertEquals "Wrong return code" '0' "${code}"
  assertEquals 'Wrong result' '## Create project formation-ci-static_user
## Associate project formation-ci-static_user and billing account
## Enable container.googleapis.com API
## Create cluster formation-ci' "${result}"
  assertEquals 'gcloud config unset project
gcloud organizations list --filter=DISPLAY_NAME=zenika.com --format=value(ID)
gcloud projects create formation-ci-static_user --organization=10000000000
gcloud alpha billing accounts list --filter=NAME:Facturation Zenika --format=value(ACCOUNT_ID)
gcloud alpha billing projects link formation-ci-static_user --billing-account AAAAAA-BBBBBB-CCCCCC
gcloud services enable container.googleapis.com --project formation-ci-static_user
gcloud container clusters create formation-ci --region europe-west1 --project formation-ci-static_user --preemptible --machine-type e2-standard-8 --num-nodes 1 --min-nodes 0 --max-nodes 3 --enable-autorepair --enable-autoscaling' "$(cat gcloud_log)"
}

# my_test1() {
#   assertTrue "[ 0 -eq 0 ]"
# }
# my_test2() {
#   assertTrue "[ 0 -eq 0 ]"
# }

# suite() {
#   suite_addTest my_test1
#   suite_addTest my_test2
# }

test_skippy() {
  assertTrue "[ 0 -eq 0 ]"
  startSkipping
  assertTrue "[ 0 -eq 1 ]"
  endSkipping
  assertTrue "[ 0 -eq 0 ]"
}

# Eat all command-line arguments before calling shunit2.
shift $#
# Load shUnit2.
source "$(which shunit2)"
