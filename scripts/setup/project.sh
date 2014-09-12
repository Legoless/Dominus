#!/bin/bash

# exit on failure
set -e

#
# Write script
#

writecfg()
{
  #
  # Write config
  #

  if [ "$TRAVIS_CONFIG" = true ]; then
    if [[ ! -z $3 ]] && [[ "$3" == "secure" ]]; then
      travis encrypt "$1='$2'" --add
    else
      echo "  - $1='$2'" >> .travis.yml
    fi
  fi

  if [ "$DOMINUS_CONFIG" = true ]; then
    echo "$1='$2'" >> dominus.cfg
  fi
}

#
# Script usage
#
usage()
{
cat << EOF
Usage: $0 <options>

This script will prepare configuration files for use with Dominus.

OPTIONS:
   -h                  Show this message
   -t                  Prepare .travis.yml for Continuous Integration
   -c                  Prepares dominus.cfg configuration file
   -a                  Prepares both .travis.yml and dominus.cfg

EOF
}

TRAVIS_CONFIG=false
DOMINUS_CONFIG=false

while getopts “htca” OPTION; do
  case $OPTION in
    h) usage; exit 1;;
    t) TRAVIS_CONFIG=true;;
    c) DOMINUS_CONFIG=true;;
    a) TRAVIS_CONFIG=true
       DOMINUS_CONFIG=true;;
   [?]) usage; exit;;
  esac
done

if [ "$TRAVIS_CONFIG" = false ] && [ "$DOMINUS_CONFIG" = false ]; then
  usage
  exit 0
fi

#
# Check if Travis CLI is available, we require it
#

if [ "$TRAVIS_CONFIG" = true ]; then

  command -v travis >/dev/null 2>&1 || { echo >&2 "[PROJECT]: Travis CLI not installed. Aborting..."; exit 1; }

  #
  # Lets build .travis.yml file
  #

  echo '[TRAVIS]: Creating .travis.yml file...'

  echo 'language: objective-c' > .travis.yml
  echo 'before_install:' >> .travis.yml
  echo '- chmod +x ./Dominus/dominus.sh' >> .travis.yml
  echo '- ./Dominus/dominus.sh update' >> .travis.yml
  echo '- ./Dominus/dominus.sh deploy init' >> .travis.yml
  echo 'install:' >> .travis.yml
  echo '- ./Dominus/dominus.sh deploy pod' >> .travis.yml
  echo 'before_script:' >> .travis.yml
  echo '- ./Dominus/dominus.sh deploy prepare' >> .travis.yml
  echo 'script:' >> .travis.yml
  echo '- ./Dominus/dominus.sh deploy build' >> .travis.yml
  echo 'after_success:' >> .travis.yml
  echo '- ./Dominus/dominus.sh deploy send' >> .travis.yml
  echo 'after_script:' >> .travis.yml
  echo '- ./Dominus/dominus.sh deploy clean' >> .travis.yml
  echo 'env:' >> .travis.yml
  echo '  global:' >> .travis.yml
fi

#
# Rewrite local variables
#

if [ "$DOMINUS_CONFIG" = true ]; then
  echo '#' > dominus.cfg
  echo '# Dominus configuration' >> dominus.cfg
  echo '#' >> dominus.cfg
  echo '' >> dominus.cfg
fi

#
# Append Global Variables if found
#

if [[ -z $LOG_LEVEL ]]; then
  echo '[PROJECT]: Enter notification log level [warn|info|debug]: '
  read LOG_LEVEL
fi

if [[ ! -z $LOG_LEVEL ]]; then
  writecfg "LOG_LEVEL" "$LOG_LEVEL"
fi

#
# Build SDK
#

if [[ -z $BUILD_SDK ]]; then
  echo '[PROJECT]: Enter deployment build SDK (iphoneos7.1): '
  read BUILD_SDK
fi

if [[ ! -z $BUILD_SDK ]]; then
  writecfg "BUILD_SDK" "$BUILD_SDK"
else
  writecfg "BUILD_SDK" "iphoneos7.1"
fi

#
# Warning builds
#

if [[ -z $ALLOWS_WARNING_BUILDS ]]; then
  echo '[PROJECT]: Allow warning builds to be deployed (true/false): '
  read ALLOWS_WARNING_BUILDS
fi

if [[ ! -z $ALLOWS_WARNING_BUILDS ]]; then
  writecfg "ALLOWS_WARNING_BUILDS" "$ALLOWS_WARNING_BUILDS"
else
  writecfg "ALLOWS_WARNING_BUILDS" "false"
fi

#
# Build number
#

if [[ -z $USE_BUILD_NUMBER ]]; then
  echo '[PROJECT]: Use build number from (travis/project or empty): '
  read USE_BUILD_NUMBER
fi

if [[ ! -z $USE_BUILD_NUMBER ]]; then
  writecfg "USE_BUILD_NUMBER" "$USE_BUILD_NUMBER"
fi


#
# Test SDK
#

if [[ -z $TEST_SDK ]]; then
  echo '[PROJECT]: Enter deployment test SDK (iphonesimulator7.1): '
  read TEST_SDK
fi

if [[ ! -z $TEST_SDK ]]; then
  writecfg "TEST_SDK" "$TEST_SDK"
else
  writecfg "TEST_SDK" "iphonesimulator7.1"
fi

#
# Deploy Branch
#

if [[ -z $DEPLOY_BRANCH ]]; then
  echo '[PROJECT]: Enter branch name that will trigger deploymnet: '
  read BUILD_SDK
fi

if [[ ! -z $DEPLOY_BRANCH ]]; then
  writecfg "DEPLOY_BRANCH" "$DEPLOY_BRANCH"
fi

#
# TestFlight Team
#

if [[ -z $TESTFLIGHT_TEAM ]]; then
  echo '[PROJECT]: Enter TestFlight Team name: '
  read TESTFLIGHT_TEAM
fi

if [[ ! -z $TESTFLIGHT_TEAM ]]; then
  writecfg "TESTFLIGHT_TEAM" "$TESTFLIGHT_TEAM"
fi

#
# TestFlight Username
#

if [[ -z $TESTFLIGHT_USERNAME ]]; then
  echo '[PROJECT]: Enter TestFlight Username: '
  read TESTFLIGHT_USERNAME
fi

if [[ ! -z $TESTFLIGHT_USERNAME ]]; then
  writecfg "TESTFLIGHT_USERNAME" "$TESTFLIGHT_USERNAME"
fi

#
# TestFlight Distribution List
#

if [[ -z $TESTFLIGHT_DISTRIBUTION_LIST ]]; then
  echo '[PROJECT]: Enter TestFlight Distribution Lists: '
  read TESTFLIGHT_DISTRIBUTION_LIST
fi

if [[ ! -z $TESTFLIGHT_DISTRIBUTION_LIST ]]; then
  writecfg "TESTFLIGHT_DISTRIBUTION_LIST" "$TESTFLIGHT_DISTRIBUTION_LIST" >> .travis.yml
fi

#
# Developer Team
#

if [[ -z $DEVELOPER_TEAM ]]; then
  echo '[PROJECT]: Enter Apple Developer Team: '
  read DEVELOPER_TEAM
fi

if [[ ! -z $DEVELOPER_TEAM ]]; then
  writecfg "DEVELOPER_TEAM" "$DEVELOPER_TEAM"
fi

#
# Developer Username
#

if [[ -z $DEVELOPER_USERNAME ]]; then
  echo '[PROJECT]: Enter Apple Developer Username: '
  read DEVELOPER_USERNAME
fi

if [[ ! -z $DEVELOPER_USERNAME ]]; then
  writecfg "DEVELOPER_USERNAME" "$DEVELOPER_USERNAME"
fi

#
# Developer Provisioning
#

if [[ -z $DEVELOPER_PROVISIONING ]]; then
  echo '[PROJECT]: Enter Provisioning Profile name: '
  read DEVELOPER_PROVISIONING
fi

if [[ ! -z $DEVELOPER_PROVISIONING ]]; then
  writecfg "DEVELOPER_PROVISIONING" "$DEVELOPER_PROVISIONING"
fi

#
# TestFlight Password
#

if [[ -z $TESTFLIGHT_PASSWORD ]]; then
  echo '[PROJECT]: Enter TestFlight Password: '
  read -s TESTFLIGHT_PASSWORD
fi

if [[ ! -z $TESTFLIGHT_PASSWORD ]]; then
  writecfg "TESTFLIGHT_PASSWORD" "$TESTFLIGHT_PASSWORD" "secure"
fi

#
# TestFlight API Token
#

if [[ -z $TESTFLIGHT_API_TOKEN ]]; then
  echo '[PROJECT]: Enter TestFlight API token: '
  read TESTFLIGHT_API_TOKEN
fi

if [[ ! -z $TESTFLIGHT_API_TOKEN ]]; then
  writecfg "TESTFLIGHT_API_TOKEN" "$TESTFLIGHT_API_TOKEN" "secure"
fi

#
# TestFlight Team Token
#

if [[ -z $TESTFLIGHT_TEAM_TOKEN ]]; then
  echo '[PROJECT]: Enter TestFlight Team token: '
  read TESTFLIGHT_TEAM_TOKEN
fi

if [[ ! -z $TESTFLIGHT_TEAM_TOKEN ]]; then
  writecfg "TESTFLIGHT_TEAM_TOKEN" "$TESTFLIGHT_TEAM_TOKEN" "secure"
fi

#
# Developer Password
#

if [[ -z $DEVELOPER_PASSWORD ]]; then
  echo '[PROJECT]: Enter Apple Developer Password: '
  read -s DEVELOPER_PASSWORD
fi

if [[ ! -z $DEVELOPER_PASSWORD ]]; then
  writecfg "DEVELOPER_PASSWORD" "$DEVELOPER_PASSWORD" "secure"
fi

#
# Developer certificate password
#

if [[ -z $DEVELOPER_IDENTITY_PASSWORD ]]; then
  echo '[PROJECT]: Enter Developer Certificate Password: '
  read -s DEVELOPER_IDENTITY_PASSWORD
fi

if [[ ! -z $DEVELOPER_IDENTITY_PASSWORD ]]; then
  writecfg "DEVELOPER_IDENTITY_PASSWORD" "$DEVELOPER_IDENTITY_PASSWORD" "secure"
fi

#
# HipChat Token
#

if [[ -z $HIPCHAT_TOKEN ]]; then
  echo '[PROJECT]: Enter HipChat API Token: '
  read HIPCHAT_TOKEN
fi

if [[ ! -z $HIPCHAT_TOKEN ]]; then
  writecfg "HIPCHAT_TOKEN" "$HIPCHAT_TOKEN" "secure"
fi

#
# HipChat Room ID
#

if [[ -z $HIPCHAT_ROOM_ID ]]; then
  echo '[PROJECT]: Enter HipChat Room: '
  read HIPCHAT_ROOM_ID
fi

if [[ ! -z $HIPCHAT_ROOM_ID ]]; then
  writecfg "HIPCHAT_ROOM_ID" "$HIPCHAT_ROOM_ID" "secure"
fi
