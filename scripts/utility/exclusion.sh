#!/bin/bash

#
# Returns first file matching path
#
check_excluded_branch()
{
  if [ -z $CI_BRANCH ] || [[ ! -z $CI_PULL_REQUEST ]] || [ -z $EXCLUDED_BRANCHES ]; then
    return 0
  fi

  message "init" "Checking excluded branches: $EXCLUDED_BRANCHES" debug normal

  if [[ $EXCLUDED_BRANCHES == *"$CI_BRANCH"* ]]; then
    message "init" "Branch: $CI_BRANCH is excluded. Aborting..." info warning
    exit 0
  fi
}

check_included_branch()
{
  if [ -z $CI_BRANCH ] || [[ ! -z $CI_PULL_REQUEST ]] || [ -z $INCLUDED_BRANCHES ]; then
    return 0
  fi

  message "init" "Checking included branches: $INCLUDED_BRANCHES" debug normal

  if [[ $INCLUDED_BRANCHES != *"$CI_BRANCH"* ]]; then
    message "init" "Branch: $CI_BRANCH is not included. Aborting..." info warning

    exit 0
  fi
}
