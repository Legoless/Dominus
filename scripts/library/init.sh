#!/bin/bash

set -e

#
# Public functions
#

init()
{
  if [[ ! -z $TRAVIS_REPO_SLUG ]]; then
    message "" "Building branch: <b>$TRAVIS_BRANCH</b>." warn warning
  else
    CURRENT_DIR=$(pwd)
    CURRENT_DIR=$(basename $CURRENT_DIR)

    message "" "Initializing repository: $CURRENT_DIR" warn warning
  fi

  message "init" "Updating Homebrew..." trace normal

  brew_update

  message "init" "Updating xctool..." trace normal

  brew_update_xctool

  message "init" "Installing CupertinoPro gem..." trace normal

  gem_install "CupertinoPro"

  message "init" "Installing AtlantisPro gem..." trace normal

  gem_install "AtlantisPro"

  message "init" "Installing CocoaPods gem..." trace normal

  message "" "Gems installed." debug normal
}

#
# Private functions
#

brew_update()
{
  brew update
}

brew_update_xctool()
{
  brew upgrade xctool

  #brew uninstall xctool
  #brew install xctool
}

gem_install()
{
  GEM=$(echo $1 | tr '[:upper:]' '[:lower:]')

  gem install $GEM --no-rdoc --no-ri --no-document --quiet
}