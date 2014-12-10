#!/bin/bash

#
# Checks if Ruby gem is installed
#
check_gem()
{
  set +e

  local RUBY_GEM_CHECK=$(gem list $1 -i)

  set -e

  echo $RUBY_GEM_CHECK
}