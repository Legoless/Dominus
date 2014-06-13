#!/bin/bash

# exit on failure
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

usage() {
cat << EOF
Usage: $0 <options>

This script will search for podfile and install Cocoapods in the directory.

OPTIONS:
   -h                  Show this message
   -d <directory>       Specific project directory (default: .)
EOF
}

while getopts “h:d:” OPTION; do
  case $OPTION in
    h) usage; exit 1;;
    d) DIRECTORY=$OPTARG;;
    [?]) usage; exit;;
  esac
done

#
# Check if Cocoapods gem is installed
#

command -v pod >/dev/null 2>&1 || { message "CocoaPods not installed. Aborting..." warn error; echo >&2 "[PODS]: Cocoapods not installed. Aborting..."; exit 1; }

#
# Fill defaults
#

if [[ -z $DIRECTORY ]]; then
  DIRECTORY='.'
fi

#
# Search for podfile
#

PODFILE_PATH=''

for f in $(find $DIRECTORY -iname podfile);
do
  if [[ -f $f ]]; then
    PODFILE_PATH=$f
    break
  fi
done

#
# If found, install pods
#
if [[ ! -z $PODFILE_PATH ]] && [[ -f $PODFILE_PATH ]]; then
  message "Installing pods: $PODFILE_PATH" debug normal

  echo '[PODS]: Installing pods:' $PODFILE_PATH

  CURRENT_DIR=$(pwd)

  DIR_PATH=$(dirname ${PODFILE_PATH})

  cd ${DIR_PATH}
  pod install
  cd ${CURRENT_DIR}

  message "CocoaPods finished installation." debug success
else
  message "Podfile not found. CocoaPods not installed." info warning

  echo '[PODS]: No podfile found.'
fi
