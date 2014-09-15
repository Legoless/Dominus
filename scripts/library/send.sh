#!/bin/sh

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

This script will search for built application (.app) file, sign it and send it to TestFlight.

OPTIONS:
   -h                  Show this message
   -f <profile>        Provisioning profile to sign executable
   -a <token>          TestFlight API token
   -t <token>          TestFlight Team Token
   -d <distribute>     Distribution list
   -r <notes>          Release notes for TestFlight
EOF
}

PROFILE=""
API_TOKEN=""
TEAM_TOKEN=""
DISTRIBUTION_LISTS=""
RELEASE_NOTES=""

while getopts “h:f:a:t:d:r:” OPTION; do
  case $OPTION in
    h) usage; exit 1;;
    f) PROFILE=$OPTARG;;
    a) API_TOKEN=$OPTARG;;
    t) TEAM_TOKEN=$OPTARG;;
    d) DISTRIBUTION_LISTS=$OPTARG;;
    r) RELEASE_NOTES=$OPTARG;;
    [?]) usage; exit;;
  esac
done

message "Sending build to distribution service..." debug normal

#
# Checks that are needed to make sure the script works
#

if [[ -z $API_TOKEN ]]; then
  message "TestFlight API token missing. Aborting..." warn error

  echo '[SEND]: TestFlight API token missing. Aborting...'
  exit 1
fi

if [[ -z $TEAM_TOKEN ]]; then
  message "TestFlight API token missing. Aborting..." warn error

  echo '[SEND]: TestFlight Team token missing. Aborting...'
  exit 1
fi

if [[ -z $DISTRIBUTION_LISTS ]]; then
  message "TestFlight Distribution list missing. Aborting..." warn error

  echo '[SEND]: TestFlight Distribution list missing. Aborting...'
  exit 1
fi


#
# Find provisioning profile
#

PROFILE_FILE=""

IFS=$'\n'

if [[ ! -z $PROFILE ]]; then
#OUTPUT="$HOME/Library/MobileDevice/Provisioning Profiles/"
  OUTPUT='.'

  for filename in $(find "$OUTPUT" -iname *.mobileprovision);
  do
    echo $filename

    PROFILE_NAME=`grep "<key>Name</key" -A1 -a $filename`
    PROFILE_NAME=${PROFILE_NAME##*<string>}
    PROFILE_NAME=${PROFILE_NAME%%</string>*}

    if [[ -f $filename ]] && [ "$PROFILE" == "$PROFILE_NAME" ]; then
      echo '[SEND]: Found profile:' $PROFILE_NAME

      PROFILE_FILE=$filename
      break
    fi
  done
else
  message "Provisioning profile name missing. Aborting..." warn error

  echo '[SEND]: Provisioning profile name not found. Aborting...'
  exit 1
fi

#
# Fill defaults
#

if [[ -z $DIR_PATH ]]; then
  DIR_PATH=$(pwd)
fi

#
# Search for workspace if project and workspace not set
#

if [[ -z $WORKSPACE ]] && [[ -z $PROJECT ]]; then
  for f in $(find $DIR_PATH -iname *.xcworkspace);
  do
    if [[ -d $f ]] && [[ $f != */project.xcworkspace ]]; then
      WORKSPACE=$f
    fi
  done

  #
  # Search for project, but only if no workspace was found
  #
  if [[ -z $WORKSPACE ]]; then
    for f in $(find $DIR_PATH -iname *.xcodeproj -maxdepth 2);
    do
      if [[ -d $f ]]; then
        PROJECT=$f
      fi
    done
  fi
fi

#
# Check if we have workspace or project at least
#
if [[ -z $WORKSPACE ]] && [[ -z $PROJECT ]]; then
  message "Nothing to send. Aborting..." warn error

  echo '[SEND]: Nothing to send. Aborting...'
  exit 0
fi

#
# Print what are we building
#

if [[ ! -z $WORKSPACE ]]; then
  message "Sending Workspace: $WORKSPACE" debug normal

  echo '[SEND]: Sending Workspace:' $WORKSPACE
  BUILD_PATH=$(dirname $WORKSPACE)
fi

if [[ ! -z $PROJECT ]]; then
  message "Sending Project: $PROJECT." debug normal

  echo '[SEND]: Sending project:' $PROJECT
  BUILD_PATH=$(dirname $PROJECT)
fi

#
# Build path
#

BUILD_PATH="$BUILD_PATH/build/"

if [ ! -d "$BUILD_PATH" ]; then
  message "Project not yet build. Aborting..." warn error

  echo '[SEND]: Build folder does not exist. Run build script first.'
  exit 1
fi

#
# Find built .app file
#

APP_PATH=""

for filename in $(find . -name *.app);
do
  if [[ -d $filename ]]; then
    message "Located compiled app: $filename" debug normal

    echo '[SEND]: Found compiled app:' $filename

    APP_PATH=$filename
    break
  fi
done

APPNAME=$(basename $APP_PATH)
APPNAME=${APPNAME%.*}

#
# Search for all installed developer identities
#

message "Searching developer identities..." debug normal

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
  message "No matching code signing identity found. Aborting..." warn error

  echo '[SEND]: Could not find code signing identity. Aborting...'
  exit 1
fi

echo '[SEND]: Found developer identity:' $IDENTITY

#
# Sign and package
#

message "Signing $APPNAME with $IDENTITY..." debug normal

echo '[SEND]: Signing and packaging the' $APPNAME 'build...'
xcrun -sdk iphoneos PackageApplication "$BUILD_PATH/$APPNAME.app" -o "$BUILD_PATH/$APPNAME.ipa" -sign "$IDENTITY" -embed "$PROFILE_FILE"

echo '[SEND]: Creating dSYM symbol ZIP package...'

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