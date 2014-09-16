#!/bin/bash

# exit on failure
set -e

#
# Public functions
#

provision()
{
  if [ "$ACTION" == "deploy" ] && [ "$DEPLOY_USE_BUILD_NUMBER" = true ]; then
    message "" "Loading devices from TestFlight and Apple developer portal..." debug normal

    message "provision" "Loading devices in TestFlight list: $TESTFLIGHT_DISTRIBUTION_LIST" trace normal

    testflight_devices

    message "provision" "Loading devices in team: $DEVELOPER_TEAM"

    apple_devices

    message "provision" "Searching for new device IDs..." debug normal

    new_devices
  fi

  apple_provisioning_profile

  FOUND_UUID=$(parse_profile_uuid $FOUND_PROFILE)

  #
  # Check if UUID is found
  #

  if [[ ! -z $FOUND_UUID ]]; then
    message "provision" "Using profile: $FOUND_UUID <b>($DEVELOPER_PROVISIONING)</b>" info success
  else
    message "provision" "Provisioning profile not found ($FOUND_UUID). Aborting..." warn error
    exit 1
  fi

  #
  # If the action is deploy
  #

  if [ "$ACTION" == "deploy" ] && [ "$DEPLOY_USE_BUILD_NUMBER" = true ]; then
    apple_add_to_provisioning
  fi

  clean_provisioning

  message "provision" "Downloading provisioning profile..." debug normal

  apple_download_profile

  #PROFILE_NAME=$(apple_download_profile)

  if [[ ! -f $PROFILE_NAME ]]; then
    message "provision" "Could not download provisioning profile. Aborting..." warn error
    exit 1
  fi

  message "provision" "Download completed (provisioning profile)." trace normal

  #
  # Install the provisioning profile...
  #

  message "provision" "Searching for UUID in profile: $PROFILE_NAME" trace normal

  PROFILE_UUID=$(find_profile_uuid $PROFILE_NAME)

  message "provision" "Installing profile: $PROFILE_UUID" debug normal

  profile_copy $PROFILE_NAME $PROFILE_UUID
}

#
# Private functions
#

testflight_devices()
{
  IFS=$'\n'

  DEVICES=$($ATLANTIS_PATH devices $TESTFLIGHT_DISTRIBUTION_LIST --team $TESTFLIGHT_TEAM --username $TESTFLIGHT_USERNAME --password $TESTFLIGHT_PASSWORD --format csv --trace)
}

apple_devices()
{
  IFS=$'\n'

  ADDED_DEVICES=$($CUPERTINO_PATH devices:list --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD --format csv --trace)
}

new_devices()
{
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
}

apple_add_devices()
{

  #
  # Add new devices to the portal
  #

  IFS=$'\n'

  for device in ${NEW_DEVICES[@]};
  do
    IFS=',' read -a data <<< "$device"

    UDID="${data[1]}"
    NAME="${data[0]}"

    message "provision" "Adding $NAME device to Apple Developer Portal..." info success

    $($CUPERTINO_PATH devices:add \"$NAME\"=$UDID --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD > /dev/null)
  done
}

apple_provisioning_profile()
{
  message "provision" "Searching for profile: $DEVELOPER_PROVISIONING" debug normal

  #
  # Get provisioning profile and find the name
  #

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
}

parse_profile_uuid()
{
  if [ "$1" != "" ]; then
    CURRENT_PROFILE=$1
    FOUND_UUID=${CURRENT_PROFILE%,*}
    FOUND_UUID=${FOUND_UUID##*,}
  fi

  echo "$FOUND_UUID"
}

#
# Add devices to profile
#

apple_add_to_provisioning()
{
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

    message "provision" "Adding $NAME ($UDID) to $PROFILE_NAME" trace normal

    message "provision" "Adding $NAME to profile: $PROFILE_NAME" debug normal

    ADD_OUTPUT=$($CUPERTINO_PATH profiles:devices:add $PROFILE_NAME $NAME=$UDID --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD)

    message "provision" "$ADD_OUTPUT" trace normal
  done
}

#
# Clean directory of any provisioning profiles, to make sure it is clean
#

clean_provisioning()
{
  find . -maxdepth 1 -type f -name "*.mobileprovision" -delete
}

#
# Download profile
#

apple_download_profile()
{
  rm -f *.mobileprovision*

  DOWNLOAD=$($CUPERTINO_PATH profiles:download $PROFILE_NAME --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD --trace)

  message "provision" "$DOWNLOAD" trace normal

  PROFILE_NAME=`find . -type f -name "*.mobileprovision" | head -n1`
}

find_profile_uuid()
{
  PROFILE_UUID=`grep UUID -A1 -a $1`

  #
  # Parse PROFILE_UUID
  #

  PROFILE_UUID=${PROFILE_UUID##*<string>}
  PROFILE_UUID=${PROFILE_UUID%%</string>*}

  echo "$PROFILE_UUID"
}


find_profile()
{
  #
  # Find provisioning profile UUID from existing provisioning profiles and check with name,
  # but we need to have a developer provisioning name.
  #

  PROFILE_UUID=""

  if [[ ! -z $2 ]]; then
    OUTPUT=$2
  else
    OUTPUT="$HOME/Library/MobileDevice/Provisioning Profiles/"
  fi

  #
  # If no profile specified, use developer provisioning global profile
  #

  if [[ ! -z $1 ]]; then
    message "provision" "Searching for profile: $1" debug normal

    for filename in $(find $OUTPUT -iname *.mobileprovision);
    do
      PROFILE_NAME=`grep "<key>Name</key" -A1 -a $filename`
      PROFILE_NAME=${PROFILE_NAME##*<string>}
      PROFILE_NAME=${PROFILE_NAME%%</string>*}

      if [[ -f $filename ]] && [ "$PROFILE" == "$PROFILE_NAME" ]; then
        message "provision" "Found profile: $PROFILE_NAME" trace normal

        PROFILE_UUID=${filename%%.*}
        PROFILE_UUID=${PROFILE_UUID##*/}

        PROFILE_FILE=$filename
        break
      fi
    done
  fi
}

#
# Copy profile to home directoy
#

profile_copy()
{
  OUTPUT="$HOME/Library/MobileDevice/Provisioning Profiles"

  if [ ! -d "$OUTPUT" ]; then
    mkdir -p "$OUTPUT"
  fi

  mv $1 "$OUTPUT/$2.mobileprovision"
}
