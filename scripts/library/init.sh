#!/bin/bash

set -e

#
# Public functions
#

init()
{
  if [[ ! -z $CI_REPOSITORY ]]; then
    message "init" "Integration (<b>$ACTION</b>) on branch: <b>$CI_BRANCH</b>." debug warning
  else
    CURRENT_DIR=$(pwd)
    CURRENT_DIR=$(basename $CURRENT_DIR)

    message "init" "Initializing repository: $CURRENT_DIR" warn warning
  fi

  #
  # Install fastlane gem, which also installs all required gems
  #

  message "init" "Checking environment and fastlane..." trace normal

  gem_install "fastlane"

  load_variables
  load_platform

  #
  # Prepare upload scripts if reporting is true
  #
  
  if [ "$REPORT" == true ]; then
    upload_prepare
  fi
}

#
# Private functions
#

brew_update()
{
  set +e
  brew update > /dev/null
  brew update > /dev/null
  set -e
}

brew_upgrade()
{
  #brew upgrade > /dev/null

  if brew outdated | grep -qx $1; then
  	brew upgrade $1
  fi
}

gem_install()
{
  local GEM=$(echo $1 | tr '[:upper:]' '[:lower:]')

  local GEM_CHECK=$(check_gem $GEM)

  if [ "$GEM_CHECK" == "false" ]; then
    gem install $@ --no-rdoc --no-ri --no-document --quiet
  fi
}

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

#
# Method checks all variables and attempts to find those that are missing.
#

load_variables()
{
  echo 'fuck you'

  find_property_list

  echo 'come on'

  #
  # Check Bundle identifier, search for it, if it is missing
  #
  #if [[ -z $BUNDLE_IDENTIFIER ]]; then
    #BUNDLE_IDENTIFIER=$(find_bundle_identifier)

    #message "init" "Loaded bundle identifier: $BUNDLE_IDENTIFIER" debug warning
  #fi

  #
  # Load project and workspace
  #

  search_targets

  if [[ ! -z $WORKSPACE ]]; then
    message "init" "Located Xcode workspace: $WORKSPACE" debug normal
  fi

  if [[ ! -z $PROJECT ]]; then
    message "init" "Located Xcode project: $PROJECT" debug normal
  fi
}

load_platform()
{

  #
  # Create build and test SDK's if both sdk and platform are specified
  #

  if [[ -z $PLATFORM ]]; then
    PLATFORM='iphone'
  fi
  
  if [[ ! -z $SDK ]] && [[ ! -z $PLATFORM ]]; then
    
    if [ "$PLATFORM" == "iphone" ]; then

      if [ "$ACTION" != "run_tests" ]; then
        BUILD_SDK=$PLATFORM'os'
        BUILD_SDK=$BUILD_SDK"$SDK"
      fi

      #
      # If no developer provisioning is defined, we will set Build SDK to be the simulator
      #

      if [[ -z $DEVELOPER_PROVISIONING ]]; then
        BUILD_SDK=$PLATFORM'simulator'
        BUILD_SDK=$BUILD_SDK"$SDK"
      fi

      TEST_SDK=$PLATFORM'simulator'$SDK
    else
      BUILD_SDK=$PLATFORM"$SDK"
      TEST_SDK=$PLATFORM"$SDK"
    fi
  fi

  #
  # We need build platform
  #

  if [[ ! -z $BUILD_PLATFORM ]]; then
    BUILD_PLATFORM='ios'
  fi

  export BUILD_SDK=$BUILD_SDK
  export TEST_SDK=$TEST_SDK
}

