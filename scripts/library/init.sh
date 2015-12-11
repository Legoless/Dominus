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

  check_variables

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

check_variables()
{
  #
  # Check Bundle identifier, search for it, if it is missing
  #
  if [[ -z $BUNDLE_IDENTIFIER ]]; then
    BUNDLE_IDENTIFIER=$(find_bundle_identifier)

    message "init" "Integration (<b>$ACTION</b>) on branch: <b>$CI_BRANCH</b>." debug warning
  fi

}

