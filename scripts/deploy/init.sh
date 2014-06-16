#!/bin/bash

set -e

message()
{
  #
  # Find notify script
  #

  NOTIFY_SCRIPT=`find . -name notify.sh | head -n1`

  IFS=$'\n'

  if [[ -f $NOTIFY_SCRIPT ]]; then
     $NOTIFY_SCRIPT -m $1 -l $2 -t $3
  fi
}

if [[ ! -z $TRAVIS_REPO_SLUG ]]; then
  message "Deploying branch: <b>$TRAVIS_BRANCH</b>." warn warning
else
  CURRENT_DIR=$(pwd)
  CURRENT_DIR=$(basename $CURRENT_DIR)

  message "Initializing repository: $CURRENT_DIR" warn warning
fi

#echo '[INIT]: Updating Homebrew'

#brew update

#
# We need XCTool to build
#

#echo '[INIT]: Installing XCTool...'

#brew uninstall xctool
#brew install xctool

#
# We need our gems to run the script
#

message "Installing gems..." debug normal

echo '[INIT]: Installing CupertinoPro gem...'

message "Installing CupertinoPro gem..." debug normal
gem install cupertinopro --no-rdoc --no-ri --no-document --quiet

echo '[INIT]: Installing AtlantisPro gem...'

message "Installing AtlantisPro gem..." debug normal
gem install atlantispro --no-rdoc --no-ri --no-document --quiet

echo '[INIT]: Installing CocoaPods gem...'

message "Installing CocoaPods gem..." debug normal
gem install cocoapods --no-rdoc --no-ri --no-document --quiet

message "Gems installed." debug normal

#
# Update submodules
#

echo '[INIT]: Updating submodules...'

message "Updating submodules..." debug normal

git pull --recurse-submodules
git submodule update --recursive

message "Submodules updated." debug normal