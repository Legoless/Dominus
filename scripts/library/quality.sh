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
  fi
}