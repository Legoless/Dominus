#!/bin/bash

set -e

#
# Public functions
#

init()
{
  if [[ ! -z $TRAVIS_REPO_SLUG ]]; then
    message "init" "Building branch: <b>$TRAVIS_BRANCH</b>." warn warning
  else
    CURRENT_DIR=$(pwd)
    CURRENT_DIR=$(basename $CURRENT_DIR)

    message "init" "Initializing repository: $CURRENT_DIR" warn warning
  fi

  message "init" "Updating Homebrew..." trace normal

  brew_update

  message "init" "Updating xctool..." trace normal

  brew_upgrade

  message "init" "Installing CupertinoPro gem..." trace normal

  gem_install "CupertinoPro"

  message "init" "Installing AtlantisPro gem..." trace normal

  gem_install "AtlantisPro"

  message "init" "Installing CocoaPods gem..." trace normal

  gem_install "CocoaPods"

  message "init" "Gems installed." debug normal
}

#
# Private functions
#

brew_update()
{
  brew update > /dev/null
}

brew_upgrade()
{
  brew upgrade > /dev/null

  #brew uninstall xctool
  #brew install xctool
}

gem_install()
{
  GEM=$(echo $1 | tr '[:upper:]' '[:lower:]')

  gem install $GEM --no-rdoc --no-ri --no-document --quiet
}