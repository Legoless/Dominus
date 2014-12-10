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

    brew cask install fauxpas

    #
    # Need to take care of FauxPas CLI tools
    #

    FAUXPAS_LOCATION=$(find_dir FauxPas.app ~/Applications)

    #echo $FAUXPAS_LOCATION

    if [[ -z $FAUXPAS_LOCATION ]]; then
      message "quality" "Error: Unable to locate FauxPas app." warn error

      exit 1
    fi

    search_targets
    set_build_path

    #select_scheme

    #message "quality" "Setuping FauxPas CLI tools..." trace normal

    #cp -f $FAUXPAS_LOCATION'/Contents/Resources/fpx.sh' /usr/local/bin/fauxpas

    message "quality" "Updating Faux Pas license..." debug normal

    fauxpas_cli updatelicense $FAUXPAS_LICENSE_TYPE $FAUXPAS_LICENSE_NAME $FAUXPAS_LICENSE_KEY

    PROJECT_TARGET=$(find_project .)

    if [[ ! -z $PROJECT_TARGET ]]; then
      message "quality" "Running Faux Pas on $PROJECT_TARGET" debug normal

      FAUXPAS_COMMAND=$PROJECT_TARGET
    else
      message "quality" "Failed: Could not find *.xcodeproj." warn error

      exit 1
    fi

    #if [[ ! -z $WORKSPACE ]] && [[ ! -z $SCHEME ]]; then
    #  message "quality" "Running Faux Pas on $WORKSPACE" debug normal
#
    #  FAUXPAS_COMMAND=$FAUXPAS_COMMAND" --workspace $WORKSPACE --scheme $SCHEME"
    #fi

    if [[ ! -z $FAUXPAS_COMMAND ]]; then

      #
      # Setup Bootstrap
      #

      setup_bootstrap

      LOG_REPORT_PATH=$(create_report_path quality $BUILD_SDK)

      FAUXPAS_OUTPUT=`fauxpas_cli check $FAUXPAS_COMMAND -o json > './report/'$LOG_REPORT_PATH'_check.json' || true`

      echo check $FAUXPAS_COMMAND

      QUALITY_REPORT=$(./Dominus/scripts/report/quality.rb './report/'$LOG_REPORT_PATH'_check.json')

      #
      # Output correct messages
      #

      NO_ERRORS=`echo $QUALITY_REPORT | grep ' 0 errors' | head -1`
      NO_WARNINGS=`echo $QUALITY_REPORT | grep ' 0 warnings' | head -1`
      NO_CONCERNS=`echo $QUALITY_REPORT | grep ' 0 concerns' | head -1`

      QUALITY_REPORT_LEVEL='success'

      if [[ -z $NO_ERRORS ]]; then
        QUALITY_REPORT_LEVEL='error'
      elif [[ -z $NO_WARNINGS ]]; then
        QUALITY_REPORT_LEVEL='warning'
      elif [[ -z $NO_CONCERNS ]]; then
        QUALITY_REPORT_LEVEL='warning'
      fi

      message "quality" "Quality check (<b>$BUILD_SDK</b>): <b>$SCHEME</b> ($QUALITY_REPORT)" info $QUALITY_REPORT_LEVEL
    else
      message "quality" "Failed: Could not find the project." warn error

      exit 1
    fi
  else
  	message "quality" "Missing Faux Pas license information, skipping..." warn warning
  fi
}

fauxpas_cli()
{
  $FAUXPAS_LOCATION/Contents/MacOS/FauxPas cli $@
}
