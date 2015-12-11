#!/bin/bash

# exit on failure
set -e

gem_install()
{
  local GEM=$(echo $1 | tr '[:upper:]' '[:lower:]')

  local GEM_CHECK=$(check_gem $GEM)

  if [ "$GEM_CHECK" == "false" ]; then
    gem install $@ --no-rdoc --no-ri --no-document --quiet
  fi
}

gem_install_specific()
{

  #
  # Check for awscli gem which is needed for 
  #

  if [ "$SPECIFIC_INSTALL_GEM" == "false" ]; then
    gem_install "specific_install"
  fi

  if [[ -z $2 ]]; then
    gem specific_install -l $1 -b $2
  else
    gem specific_install -l $1
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
