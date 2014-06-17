#!/bin/bash

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

# exit on failure
set -e

usage() {
cat << EOF
Usage: $0 <options>

This script will search for podfile and install Cocoapods in the directory.

OPTIONS:
   -h                   Display this message
   -a <path>            Path to AtlantisPro executable
   -c <path>            Path to CupertinoPro executable
EOF
}

while getopts “a:c:” OPTION; do
  case $OPTION in
    h) usage; exit 1;;
    a) ATLANTIS_PATH=$OPTARG;;
    c) CUPERTINO_PATH=$OPTARG;;
    [?]) usage; exit;;
  esac
done

#
# A safety check if all executables are available
#

command -v $ATLANTIS_PATH >/dev/null 2>&1 || { message "AtlantisPro not installed. Aborting..." warn error; echo >&2 "[PROFILE]: AtlantisPro not installed. Aborting..."; exit 1; }
command -v $CUPERTINO_PATH >/dev/null 2>&1 || { message "CupertinoPro not installed. Aborting..." warn error; echo >&2 "[PROFILE]: CupertinoPro not installed. Aborting..."; exit 1; }

#
# Load all devices on TestFlight for specific distribution list
#

IFS=$'\n'

message "Loading devices from TestFlight and Apple developer portal" debug normal

echo '[PREPARE]: Loading devices in list:' $TESTFLIGHT_DISTRIBUTION_LIST

DEVICES=$($ATLANTIS_PATH devices $TESTFLIGHT_DISTRIBUTION_LIST --team $TESTFLIGHT_TEAM --username $TESTFLIGHT_USERNAME --password $TESTFLIGHT_PASSWORD --format csv --trace)

#
# Load all devices from Apple Developer portal
#

echo '[PREPARE]: Loading devices in team:' $DEVELOPER_TEAM

ADDED_DEVICES=$($CUPERTINO_PATH devices:list --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD --format csv --trace)

echo '[PREPARE]: Searching for new device IDs...'

message "Searching for new device IDs..." debug normal

#
# Find all new devices
#

NEW_DEVICES=()

DEVICE_INDEX=-1

FOUND=false

for device in $DEVICES;
do
  DEVICE_INDEX=$(( DEVICE_INDEX+1 ))
  FOUND=false

  #
  # Skip first line, which is only a descriptor
  #
  if (($DEVICE_INDEX == 0)); then
    continue;
  fi

  #
  # Get UDID
  #

  IFS=',' read -a data <<< "$device"

  UDID="${data[1]}"

  #
  # Find UDID in existing
  #

  IFS=$'\n'

  ADDED_INDEX=-1

  for old_device in $ADDED_DEVICES;
  do
    ADDED_INDEX=$(( ADDED_INDEX+1 ))

    if (($ADDED_INDEX == 0)); then
      continue
    fi

    IFS=',' read -a device_data <<< "$old_device"

    EXISTING_UDID="${device_data[1]}"

    if [ "$UDID" == "$EXISTING_UDID" ]; then
      FOUND=true
      break;
    fi
  done

  if [ "$FOUND" != true ]; then
    NEW_DEVICES+=($device)
  fi

done

#
# Found new devices, add them to the portal
#
IFS=$'\n'

for device in ${NEW_DEVICES[@]};
do
  IFS=',' read -a data <<< "$device"

  UDID="${data[1]}"
  NAME="${data[0]}"

  message "Adding $NAME to Developer Portal" info success

  echo '[PREPARE]: Adding' $NAME 'device to Apple Developer Portal...'

  $($CUPERTINO_PATH devices:add \"$NAME\"=$UDID --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD > /dev/null)
done

message "Searching for profile: $DEVELOPER_PROVISIONING" debug normal

#
# Get provisioning profile and find the name
#

echo '[PREPARE]: Searching for provisioning profile:' $DEVELOPER_PROVISIONING'...'

IFS=$'\n'

PROFILES=$($CUPERTINO_PATH profiles:list --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD --format csv)

PROFILE_INDEX=-1

FOUND_PROFILE=""

for profile in $PROFILES;
do
  PROFILE_INDEX=$(( PROFILE_INDEX+1 ))

  #
  # Skip first line, which is only a descriptor
  #
  if (($PROFILE_INDEX == 0)); then
    continue;
  fi

#echo 'LOOKING AT:' $profile

  #
  # Get profile name
  #

  IFS=',' read -a data <<< "$profile"

  PROFILE_NAME="${data[0]}"

  if [ "$PROFILE_NAME" == "$DEVELOPER_PROVISIONING" ]; then
    FOUND_PROFILE=$profile
    break;
  fi
done

#
# If there is no profile yet, we shall create it, right?
#

if [ "$FOUND_PROFILE" != "" ]; then
  FOUND_UUID=${FOUND_PROFILE%,*}
  FOUND_UUID=${FOUND_UUID##*,}

  message "Using profile: <b>$FOUND_UUID</b>" info success

  echo '[PREPARE]: Using profile: '$FOUND_UUID
else
  message "Provisioning profile not found. Aborting" warn error

  echo '[PREPARE]: Provisioning profile not found. Aborting...'
  exit 1
fi

#
# Add devices to profile
#

DEVICE_INDEX=-1

for device in $DEVICES;
do
  DEVICE_INDEX=$(( DEVICE_INDEX+1 ))

  #
  # Skip first line, which is only a descriptor
  #
  if (($DEVICE_INDEX == 0)); then
    continue;
  fi

  IFS=',' read -a data <<< "$device"

  UDID="${data[1]}"
  NAME="${data[0]}"

  echo '[PREPARE]: Adding' $NAME '('$UDID') to' $PROFILE_NAME

  message "Adding $NAME to profile: $PROFILE_NAME" debug normal

  ADD_OUTPUT=$($CUPERTINO_PATH profiles:devices:add $PROFILE_NAME $NAME=$UDID --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD)

  echo '[PREPARE]:' $ADD_OUTPUT
done

#
# Clean directory of any provisioning profiles, to make sure it is clean
#

find . -maxdepth 1 -type f -name "*.mobileprovision" -delete

#
# Download profile
#

message "Downloading new provisioning profile..." debug normal

echo '[PREPARE]: Downloading new provisioning profile...'

$($CUPERTINO_PATH profiles:download $PROFILE_NAME --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD)
#DOWNLOAD=$($CUPERTINO_PATH profiles:download $PROFILE_NAME --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD --trace)

#echo [PREPARE]: $DOWNLOAD

PROFILE_NAME=`find . -type f -name "*.mobileprovision" | head -n1`

if [[ ! -f $PROFILE_NAME ]]; then
  message "Could not download provisioning profile. Aborting..." warn error

  echo '[PREPARE]: Could not download provisioning profile. Aborting...'
  exit 1
fi

#
# Install the provisioning profile...
#

PROFILE_UUID=`grep UUID -A1 -a $PROFILE_NAME | grep -o "[-A-Z0-9]\{36\}"`

echo '[PREPARE]: Installing profile with ID' $PROFILE_UUID

message "Installing profile: $PROFILE_UUID" debug normal

#
# Copy profile to home directoy
#

OUTPUT="$HOME/Library/MobileDevice/Provisioning Profiles"

if [ ! -d "$OUTPUT" ]; then
  mkdir -p "$OUTPUT"
fi

mv $PROFILE_NAME "$OUTPUT/$PROFILE_UUID.mobileprovision"
