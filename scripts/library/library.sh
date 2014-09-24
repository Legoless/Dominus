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

  PODFILE_PATH=$(find_file 'podfile')

  #
  # If found, install pods
  #

  if [[ ! -z $PODFILE_PATH ]]; then
    message "library" "Installing pods: $PODFILE_PATH" debug normal

    CURRENT_DIR=$(pwd)

    DIR_PATH=$(dirname ${PODFILE_PATH})

    cd ${DIR_PATH}
    pod install
    cd ${CURRENT_DIR}

    message "library" "CocoaPods finished installation." debug success
  else
    message "library" "Podfile not found. CocoaPods not installed." info warning
  fi
}
