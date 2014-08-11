#!/bin/bash

#
# Check if script path is available...
#

if [[ -z $SCRIPT_PATH ]]; then
  echo '[ENV]: Script path not found. Aborting...'
  exit 1
fi

#
# Update and install Homebrew
#

echo '[ENV]: Installing Homebrew...'

ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"

echo '[ENV]: Initializing deploy system...'

#
# Running init command to install basic gems
#

$SCRIPT_PATH'deploy/init.sh'

#
# Install LiftOff
#

echo '[ENV]: Installing LiftOff...'

brew tap thoughtbot/formulae
brew install liftoff

#
# Gem install Travis
#

echo '[ENV]: Installing Travis-CLI'

gem install travis
travis login