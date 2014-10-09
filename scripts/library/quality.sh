#!/bin/bash

# exit on failure
set -e

#
# Public functions
#

quality()
{
  if [[ ! -z $FAUXPAS_LICENSE_TYPE ]]; then
    message "quality" "Installing quality tool prerequisites..." debug normal

    brew tap caskroom/cask
    brew install brew-cask

    message "quality" "Installing Faux Pas..." debug normal

    brew cask install faux-pas

    #
    # Need to take care of FauxPas CLI tools
    #

    FAUXPAS_LOCATION=$(find_dir FauxPas.app ~/Applications)

    #echo $FAUXPAS_LOCATION

    if [[ -z $FAUXPAS_LOCATION ]]; then
      message "quality" "Error: Unable to locate FauxPas app." warn error

      exit 1
    fi

    #message "quality" "Setuping FauxPas CLI tools..." trace normal

    #cp -f $FAUXPAS_LOCATION'/Contents/Resources/fpx.sh' /usr/local/bin/fauxpas

    message "quality" "Updating Faux Pas license..." debug normal

    fauxpas_cli updatelicense $FAUXPAS_LICENSE_TYPE $FAUXPAS_LICENSE_NAME $FAUXPAS_LICENSE_KEY

    PROJECT_TARGET=$(find_project .)

    if [[ ! -z $PROJECT_TARGET ]]; then
      message "quality" "Running Faux Pas on $PROJECT_TARGET" debug normal

      LOG_REPORT_PATH=$(create_report_path quality $BUILD_SDK)

      FAUXPAS_OUTPUT=`fauxpas_cli check $PROJECT_TARGET -o json > './report/'$LOG_REPORT_PATH'_check.json' || true`

      message "quality" "Finished running quality check." debug normal
    else
      message "quality" "Failed: Could not find *.xcodeproj." warn error
    fi
  else
  	message "quality" "Missing Faux Pas license information, aborting..." warn warning
  fi
}

fauxpas_cli()
{
  $FAUXPAS_LOCATION cli $@
}