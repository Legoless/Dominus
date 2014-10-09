#!/bin/bash

# exit on failure
set -e

#
# Public functions
#

quality()
{
  if [[ ! -z $FAUXPAS_LICENSE_TYPE ]]; then
    brew tap caskroom/cask
    brew install brew-cask

    message "quality" "Installing Faux Pas..." debug normal

    brew cask install faux-pas

    message "quality" "Updating Faux Pas license..." debug normal

    fauxpas updatelicense $FAUXPAS_LICENSE_TYPE $FAUXPAS_LICENSE_NAME $FAUXPAS_LICENSE_KEY

    PROJECT_TARGET=$(find_project .)

    if [[ ! -z $PROJECT_TARGET ]]; then
      message "quality" "Running Faux Pas on $PROJECT_TARGET" debug normal

      LOG_REPORT_PATH=$(create_report_path quality $BUILD_SDK)

      fauxpas check $PROJECT_TARGET -o json > './report/'$LOG_REPORT_PATH'_check.json'

      message "quality" "Finished running quality check." debug normal
    else
      message "quality" "Failed: Could not find *.xcodeproj." info error
    fi
  fi
}