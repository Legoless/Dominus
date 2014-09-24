#!/bin/sh

# exit on failure
set -e

send()
{
  #
  # Check if we should deploy
  #
  
  if [[ $TRAVIS_BRANCH != $DEPLOY_BRANCH ]] && [[ ! -z $TRAVIS_BRANCH ]] && [[ ! -z $DEPLOY_BRANCH ]]; then
    message "send" "Skipping deployment: $TRAVIS_BRANCH branch not deployed (requires: $DEPLOY_BRANCH)." debug warning

    return
 fi

  PROFILE=$DEVELOPER_PROVISIONING
  API_TOKEN=$TESTFLIGHT_API_TOKEN
  TEAM_TOKEN=$TESTFLIGHT_TEAM_TOKEN
  DISTRIBUTION_LISTS=$TESTFLIGHT_DISTRIBUTION_LIST
  RELEASE_NOTES=$(construct_release_notes)

  message "send" "Sending build to distribution service..." debug normal

  #
  # Find provisioning profile
  #

  find_profile

  #
  # Fill defaults
  #

  if [[ -z $DIR_PATH ]]; then
    DIR_PATH=$(pwd)
  fi

  #
  # Search for workspace if project and workspace not set
  #

  search_targets

  #
  # Check if we have workspace or project at least
  #
  if [[ -z $WORKSPACE ]] && [[ -z $PROJECT ]]; then
    message "send" "Nothing to send. Aborting..." warn error

    exit 0
  fi

  #
  # Print what are we building
  #

  if [[ ! -z $WORKSPACE ]]; then
    message "send" "Sending Workspace: $WORKSPACE" debug normal

    BUILD_PATH=$(dirname $WORKSPACE)
  fi

  if [[ ! -z $PROJECT ]]; then
    message "send" "Sending Project: $PROJECT." debug normal

    BUILD_PATH=$(dirname $PROJECT)
  fi

  #
  # Build path
  #

  BUILD_PATH="$BUILD_PATH/build/"

  if [ ! -d "$BUILD_PATH" ]; then
    message "send" "Project uild folder does not exist yet. Aborting..." warn error

    exit 1
  fi

  #
  # Find built .app file
  #

  APP_PATH=$(find_file *.app)

  APPNAME=$(basename $APP_PATH)
  APPNAME=${APPNAME%.*}

  #
  # Search for all installed developer identities
  #

  message "send" "Searching developer identities..." debug normal

  #
  # We must find ALL developer identities in provisioning profile, so we can sign with one that is correct.
  # First get the developer keys base64 code from provisioning profile.
  #

  KEYS=`strings $PROFILE_FILE | sed -n "/<data>/,/<\/data>/p" | tr -d '\n'`

  DEVELOPER_KEYS=()

  while [[  $KEYS == *\<data\>* ]]
  do

    #
    # Cut first key
    #
    KEY=${KEYS%%</data>*}
    KEY=${KEY#*<data>}

    DECRYPTED=`echo $KEY | base64 --decode | strings`

    # Cut away the parsed data
    KEYS=${KEYS#*</data>}

    DECRYPTED=${DECRYPTED#*iPhone}
    DECRYPTED=${DECRYPTED%%)*}
    DECRYPTED=$DECRYPTED')'
    DECRYPTED='iPhone'$DECRYPTED

    DECRYPTED="${DECRYPTED#"${DECRYPTED%%[![:space:]]*}"}"
    DECRYPTED="${DECRYPTED%"${DECRYPTED##*[![:space:]]}"}"

  #echo '[SEND]: Profile key' $DECRYPTED

    DEVELOPER_KEYS+=($DECRYPTED)
  done;

  #
  # We got developer keys in profile, find the correct key to sign now
  #

  IDENTITIES=`security find-identity -v | grep "iPhone"`

  IDENTITY=""

  for ident in $IDENTITIES;
  do
    DEV_NAME=${ident#*\"}
    DEV_NAME=${DEV_NAME%\"*}
    DEV_NAME="${DEV_NAME#"${DEV_NAME%%[![:space:]]*}"}"
    DEV_NAME="${DEV_NAME%"${DEV_NAME##*[![:space:]]}"}"

  #echo '[SEND]: Identity:' $DEV_NAME

    #
    # Go through developer keys and find a matching developer name
    #

    IFS=$'\n'

    for dev_key in "${DEVELOPER_KEYS[@]}";
    do
  #echo '[SEND]: Comparing:' $dev_key 'to' $DEV_NAME

      if [ "$dev_key" == "$DEV_NAME" ]; then
        IDENTITY=$DEV_NAME
        break
      fi

    done

    #
    # Stop looping if found key
    #

    if [[ ! -z $IDENTITY ]]; then
      break;
    fi
  done

  if [[ -z $IDENTITY ]]; then
    message "send" "No matching code signing identity found. Aborting..." warn error

    exit 1
  fi

  message "send" "Found developer identity:' $IDENTITY" trace normal

  #
  # Sign and package
  #

  message "send" "Signing $APPNAME with $IDENTITY..." debug normal

  xcrun -sdk iphoneos PackageApplication "$BUILD_PATH/$APPNAME.app" -o "$BUILD_PATH/$APPNAME.ipa" -sign "$IDENTITY" -embed "$PROFILE_FILE"

  message "send" "Creating dSYM symbol ZIP package..." trace normal

  zip -r -q -9 "$BUILD_PATH/$APPNAME.app.dSYM.zip" "$BUILD_PATH/$APPNAME.app.dSYM"

  #
  # Add release notes
  #

  if [[ -z $RELEASE_NOTES ]]; then
    RELEASE_NOTES="$APPNAME Automated Build"
  fi

  echo '[SEND]: Uploading package to TestFlight...'

  #
  # Upload to TestFlight
  #

  message "Uploading package to TestFlight..." debug normal

  TESTFLIGHT_OUTPUT=`curl http://testflightapp.com/api/builds.json \
  -F file="@$BUILD_PATH/$APPNAME.ipa" \
  -F dsym="@$BUILD_PATH/$APPNAME.app.dSYM.zip" \
  -F api_token="$API_TOKEN" \
  -F team_token="$TEAM_TOKEN" \
  -F distribution_lists="$DISTRIBUTION_LISTS" \
  -F notes="$RELEASE_NOTES" -v \
  -F notify="TRUE" -w "%{http_code}"`

  message "Deploy complete. <b>$APPNAME</b> was distributed to <b>$DISTRIBUTION_LISTS</b>." warn success
}

construct_release_notes()
{
  #
  # Create release notes for deployment
  #

  RELEASE_NOTES=''

  #
  # Append app name
  #

  XCODE_PROJECT=`find . -iname *.xcodeproj -type d -maxdepth 2 | head -1`

  if [[ ! -z $XCODE_PROJECT ]]; then
    PROJECT_NAME=`xcodebuild -project $XCODE_PROJECT -showBuildSettings | grep PRODUCT_NAME | grep FULL --invert-match | head -1 | sed -e 's/^ *//' -e 's/ *$//'`
  fi

  if [[ ! -z $PROJECT_NAME ]]; then
    PREFIX='PRODUCT_NAME = '
    PROJECT_NAME=${PROJECT_NAME#$PREFIX}

    RELEASE_NOTES=$PROJECT_NAME
  fi

  # Find a correct property list
  PROPERTY_LIST=$(find_property_list)

  #
  # Append version and build to release notes
  #

  if [[ ! -z $PROPERTY_LIST ]]; then
    message "send" "Creating release notes from property list: $PROPERTY_LIST"

    APP_VERSION=$(read_property $PROPERTY_LIST CFBundleShortVersionString)

    #
    # Override bundle name here if we have it
    #

    BUNDLE_NAME=$(read_property $PROPERTY_LIST CFBundleDisplayName)

    if [[ ! -z $BUNDLE_NAME ]]; then
      RELEASE_NOTES=$BUNDLE_NAME
    fi

    RELEASE_NOTES="$RELEASE_NOTES ($APP_VERSION"

    if [[ ! -z $TRAVIS_BUILD_NUMBER ]]; then
      RELEASE_NOTES=$RELEASE_NOTES'.'$TRAVIS_BUILD_NUMBER
    else
      PLIST_BUILD_NUMBER=$(read_property $PROPERTY_LIST CFBundleVersion)
      RELEASE_NOTES=$RELEASE_NOTES'.'$PLIST_BUILD_NUMBER
    fi

    RELEASE_NOTES=$RELEASE_NOTES')'
  fi

  #
  # Append branch
  #

  BUILD_BRANCH=''

  if [[ ! -z $TRAVIS_BRANCH ]]; then
    BUILD_BRANCH=$TRAVIS_BRANCH
  else
    BUILD_BRANCH=`git rev-parse --abbrev-ref HEAD`
  fi

  BUILD_BRANCH="$(tr '[:lower:]' '[:upper:]' <<< ${BUILD_BRANCH:0:1})${BUILD_BRANCH:1}"

  if [[ ! -z $BUILD_BRANCH ]]; then
    RELEASE_NOTES=$RELEASE_NOTES' '$BUILD_BRANCH' automated build.'
  else
    RELEASE_NOTES=$RELEASE_NOTES' automated build.'
  fi

  #
  # Check for Travis CI history
  #

  if [[ ! -z $TRAVIS_COMMIT_RANGE ]]; then
    RELEASE_NOTES=$RELEASE_NOTES' Changes from last version:\n'

    GIT_HISTORY=`git log $TRAVIS_COMMIT_RANGE --no-merges --format="%s"`

    IFS=$'\n'

    for history in $GIT_HISTORY;
    do
      RELEASE_NOTES=$RELEASE_NOTES' - '$history$'\n'
    done
  fi

  return "$RELEASE_NOTES"
}

find_property_list()
{
  # Find a correct property list
  PROPERTY_LIST=''

  for filename in $(find . -iname *-Info.plist);
  do

    #
    # Select property list if it does not contain Tests or Pods
    #

    if [[ ! $filename == *Tests* ]] && [[ ! $filename == *Pods* ]]; then
      PROPERTY_LIST=$filename
      break
    fi
  done

  echo $PROPERTY_LIST
}

read_property()
{
  PROPERTY=`/usr/libexec/plistbuddy -c Print:$2: $1`

  echo $PROPERTY
}