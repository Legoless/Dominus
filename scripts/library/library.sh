#!/bin/bash

# exit on failure
set -e

#
# Public functions
#

library()
{
  #
  # Search for podfile
  #

  PODFILE_PATH=$(find_file "podfile")

  #
  # If found, install pods
  #

  if [[ ! -z $PODFILE_PATH ]]; then
    message "Installing pods: $PODFILE_PATH" debug normal

    message "pods" "[PODS]: Installing pods: $PODFILE_PATH" trace normal

    CURRENT_DIR=$(pwd)

    DIR_PATH=$(dirname ${PODFILE_PATH})

    cd ${DIR_PATH}
    pod install
    cd ${CURRENT_DIR}

    message "" "CocoaPods finished installation." debug success
  else
    message "" "Podfile not found. CocoaPods not installed." info warning
  fi
}
