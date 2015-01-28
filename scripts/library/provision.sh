#!/bin/bash

# exit on failure
set -e

#
# Public functions
#

provision()
{
  #
  # If we are building for simulator, no provisioning profiles needed
  #

  if [[ $BUILD_SDK == *simulator* ]]; then
    return 0
  fi

  #
  # Install Cupertino gem only if we are not on Simulator
  #

  message "provision" "Installing Cupertino gem..." trace normal

  gem_install "Cupertino"

  #
  # If deploy update devices is set to true, then we install the gem
  #

  NEW_DEVICES=()
  NEW_DEVICES_COUNT=0

  if [ "$ACTION" == "deploy" ] && [ "$DEPLOY_UPDATE_DEVICES" = true ]; then
    message "provision" "Loading devices in Apple Developer team: $DEVELOPER_TEAM" debug normal

    apple_devices

    message "provision" "Installing AtlantisPro to connect to distribution services..." trace normal

    gem_install "AtlantisPro"

    message "provision" "Loading devices from TestFlight app..." trace normal

    testflight_devices

    message "provision" "Loading devices from Crashlytics Beta..." trace normal

    crashlytics_devices

    message "provision" "Found $NEW_DEVICES_COUNT new devices..." debug normal

    apple_add_devices
  fi

  apple_provisioning_profile

  FOUND_UUID=$(parse_profile_uuid $FOUND_PROFILE)

  #
  # Check if UUID is found
  #

  if [[ ! -z $FOUND_UUID ]]; then
    message "provision" "Using profile: $FOUND_UUID <b>($DEVELOPER_PROVISIONING)</b>" info success
  else
    message "provision" "Provisioning profile not found ($DEVELOPER_PROVISIONING). Aborting..." warn error
    exit 1
  fi

  #
  # If the action is deploy, we are updating devices and have at least 1 new device
  #

  if [ "$ACTION" == "deploy" ] && [ "$DEPLOY_UPDATE_DEVICES" = true ] && [ "$NEW_DEVICES_COUNT" != 0 ]; then
    apple_add_to_provisioning
  fi

  clean_provisioning

  message "provision" "Downloading provisioning profile..." debug normal

  apple_download_profile

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
  IFS=$''

  if [[ ! -z $TESTFLIGHT_TEAM ]] && [[ ! -z $TESTFLIGHT_USERNAME ]] && [[ ! -z $TESTFLIGHT_PASSWORD ]]; then
    local TESTFLIGHT_COMMAND="$ATLANTIS_PATH devices --team $TESTFLIGHT_TEAM --username $TESTFLIGHT_USERNAME --password $TESTFLIGHT_PASSWORD --format csv --trace --service TestFlight"

    if [[ ! -z $TESTFLIGHT_DISTRIBUTION_LIST ]]; then
      TESTFLIGHT_COMMAND=$TESTFLIGHT_COMMAND" --group $TESTFLIGHT_DISTRIBUTION_LIST"
    fi

    local DEVICES=`eval $TESTFLIGHT_COMMAND`

    new_devices $DEVICES
  fi
}

crashlytics_devices()
{
  IFS=$''

  if [[ ! -z $CRASHLYTICS_ORGANIZATION ]] && [[ ! -z $CRASHLYTICS_USERNAME ]] && [[ ! -z $CRASHLYTICS_PASSWORD ]]; then
    local CRASHLYTICS_COMMAND="$ATLANTIS_PATH devices --team $CRASHLYTICS_ORGANIZATION --username $CRASHLYTICS_USERNAME --password $CRASHLYTICS_PASSWORD --format csv --trace --service Crashlytics"

    if [[ ! -z $CRASHLYTICS_DISTRIBUTION_LIST ]]; then
      CRASHLYTICS_COMMAND=$CRASHLYTICS_COMMAND" --group $CRASHLYTICS_DISTRIBUTION_LIST"
    fi

    local DEVICES=`eval $CRASHLYTICS_COMMAND`

    new_devices $DEVICES
  fi
}

apple_devices()
{
  IFS=$'\n'

  ADDED_DEVICES=$($CUPERTINO_PATH devices:list --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD --format csv --trace)
}

#
# Call this method with parameter data from AtlantisPro gem, it will add to 
#

new_devices()
{
  IFS=$'\n'
  #
  # Find all new devices
  #

  DEVICE_INDEX=-1

  for device in $1;
  do
    DEVICE_INDEX=$(( DEVICE_INDEX+1 ))

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
    # Use UDID only if it is not on portal or in new device array
    #

    local DEVICE_ON_PORTAL=$(find_device $UDID "${ADDED_DEVICES[@]}")
    local DEVICE_IN_ARRAY=$(find_device $UDID "${NEW_DEVICES[@]}")

    if [ "$DEVICE_ON_PORTAL" == "false" ] && [ "$DEVICE_IN_ARRAY" == "false" ]; then
      NEW_DEVICES+=($device)
      NEW_DEVICES_COUNT=$((NEW_DEVICES_COUNT + 1))
    fi
  done
}

#
# Function finds UDID in devices
# - $1 = UDID
# - $2 = device array
#

find_device()
{
  local FOUND='false'

  IFS=$'\n'

  #
  # Skip first line
  #
  
  ADDED_INDEX=-1

  for old_device in $2;
  do
    ADDED_INDEX=$(( ADDED_INDEX+1 ))

    if (($ADDED_INDEX == 0)); then
      continue
    fi

    IFS=',' read -a device_data <<< "$old_device"

    EXISTING_UDID="${device_data[1]}"

    if [ "$1" == "$EXISTING_UDID" ]; then
      FOUND='true'
      break;
    fi
  done

  echo $FOUND
}

apple_provisioning_profile()
{
  message "provision" "Searching for profile: $DEVELOPER_PROVISIONING" debug normal

  #
  # Get provisioning profile and find the name
  #

  IFS=$'\n'

  PROFILES=$($CUPERTINO_PATH profiles:list --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD --format csv --trace)

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
    IFS=',' read -a data <<< "$1"

    FOUND_UUID="${data[2]}"
  fi

  echo "$FOUND_UUID"
}

#
# Add devices to profile
#

apple_add_to_provisioning()
{
  if [ "$NEW_DEVICES_COUNT" != 0 ]; then
    message "provision" "Updating provisioning profile ($PROFILE_NAME) on Apple Developer portal..." debug normal

    IFS=$''

    for device in ${NEW_DEVICES[@]};
    do
      IFS=',' read -a data <<< "$device"

      UDID="${data[1]}"
      NAME="${data[0]}"

      message "provision" "Adding $NAME to $PROFILE_NAME" debug normal

      ADD_OUTPUT=$($CUPERTINO_PATH profiles:devices:add $PROFILE_NAME $NAME=$UDID --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD)

      message "provision" "$ADD_OUTPUT" trace normal
    done
  fi
}

apple_add_devices()
{
  if [ "$NEW_DEVICES_COUNT" != 0 ]; then

    message "provision" "New devices found ($NEW_DEVICES_COUNT), adding to Apple Developer portal..." debug normal

    #
    # Add new devices to the portal
    #

    IFS=$''

    for device in ${NEW_DEVICES[@]};
    do
      IFS=',' read -a data <<< "$device"

      UDID="${data[1]}"
      NAME="${data[0]}"

      message "provision" "Adding $NAME ($UDID) device to Apple Developer Portal..." info success

      $($CUPERTINO_PATH devices:add \"$NAME\"=$UDID --team $DEVELOPER_TEAM --username $DEVELOPER_USERNAME --password $DEVELOPER_PASSWORD > /dev/null)
    done
  fi
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

  #message "provision" "$DOWNLOAD" trace normal

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
