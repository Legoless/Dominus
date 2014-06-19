#!/bin/bash

#
# Check if Travis CLI is available, we require it
#

command -v travis >/dev/null 2>&1 || { echo >&2 "[TRAVIS]: Travis CLI not installed. Aborting..."; exit 1; }

#
# Lets build .travis.yml file
#

echo '[TRAVIS]: Creating .travis.yml file...'

echo 'branches:' > .travis.yml
echo '  only:' >> .travis.yml
echo '  - test' >> .travis.yml
echo 'language: objective-c' >> .travis.yml
echo 'before_install:' >> .travis.yml
echo '- chmod +x ./Dominus/dominus.sh' >> .travis.yml
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

#
# Append Global Variables if found
#

if [[ -z $LOG_LEVEL ]]; then
  echo '[TRAVIS]: Enter notification log level [warn|info|debug]: '
  read LOG_LEVEL
fi

if [[ ! -z $LOG_LEVEL ]]; then
  echo "  - LOG_LEVEL='$LOG_LEVEL'" >> .travis.yml
fi

#
# Build SDK
#

if [[ -z $BUILD_SDK ]]; then
  echo '[TRAVIS]: Enter deployment build SDK (iphoneos7.1): '
  read BUILD_SDK
fi

if [[ ! -z $BUILD_SDK ]]; then
  echo "  - BUILD_SDK='$BUILD_SDK'" >> .travis.yml
fi

#
# Test SDK
#

if [[ -z $TEST_SDK ]]; then
  echo '[TRAVIS]: Enter deployment test SDK (iphonesimulator7.1): '
  read TEST_SDK
fi

if [[ ! -z $TEST_SDK ]]; then
  echo "  - TEST_SDK='$TEST_SDK'" >> .travis.yml
fi

#
# TestFlight Team
#

if [[ -z $TESTFLIGHT_TEAM ]]; then
  echo '[TRAVIS]: Enter TestFlight Team name: '
  read TESTFLIGHT_TEAM
fi

if [[ ! -z $TESTFLIGHT_TEAM ]]; then
  echo "  - TESTFLIGHT_TEAM='$TESTFLIGHT_TEAM'" >> .travis.yml
fi

#
# TestFlight Username
#

if [[ -z $TESTFLIGHT_USERNAME ]]; then
  echo '[TRAVIS]: Enter TestFlight Username: '
  read TESTFLIGHT_USERNAME
fi

if [[ ! -z $TESTFLIGHT_USERNAME ]]; then
  echo "  - TESTFLIGHT_USERNAME='$TESTFLIGHT_USERNAME'" >> .travis.yml
fi

#
# TestFlight Distribution List
#

if [[ -z $TESTFLIGHT_DISTRIBUTION_LIST ]]; then
  echo '[TRAVIS]: Enter TestFlight Distribution Lists: '
  read TESTFLIGHT_DISTRIBUTION_LIST
fi

if [[ ! -z $TESTFLIGHT_DISTRIBUTION_LIST ]]; then
  echo "  - TESTFLIGHT_DISTRIBUTION_LIST='$TESTFLIGHT_DISTRIBUTION_LIST'" >> .travis.yml
fi

#
# Developer Team
#

if [[ -z $DEVELOPER_TEAM ]]; then
  echo '[TRAVIS]: Enter Apple Developer Team: '
  read DEVELOPER_TEAM
fi

if [[ ! -z $DEVELOPER_TEAM ]]; then
  echo "  - DEVELOPER_TEAM='$DEVELOPER_TEAM'" >> .travis.yml
fi

#
# Developer Username
#

if [[ -z $DEVELOPER_USERNAME ]]; then
  echo '[TRAVIS]: Enter Apple Developer Username: '
  read DEVELOPER_USERNAME
fi

if [[ ! -z $DEVELOPER_USERNAME ]]; then
echo "  - DEVELOPER_USERNAME='$DEVELOPER_USERNAME'" >> .travis.yml
fi

#
# Developer Provisioning
#

if [[ -z $DEVELOPER_PROVISIONING ]]; then
  echo '[TRAVIS]: Enter Provisioning Profile name: '
  read DEVELOPER_PROVISIONING
fi

if [[ ! -z $DEVELOPER_PROVISIONING ]]; then
  echo "  - DEVELOPER_PROVISIONING='$DEVELOPER_PROVISIONING'" >> .travis.yml
fi

#
# TestFlight Password
#

if [[ -z $TESTFLIGHT_PASSWORD ]]; then
  echo '[TRAVIS]: Enter TestFlight Password: '
  read -s TESTFLIGHT_PASSWORD
fi

if [[ ! -z $TESTFLIGHT_PASSWORD ]]; then
  travis encrypt "TESTFLIGHT_PASSWORD='$TESTFLIGHT_PASSWORD'" --add
fi

#
# TestFlight API Token
#

if [[ -z $TESTFLIGHT_API_TOKEN ]]; then
  echo '[TRAVIS]: Enter TestFlight API token: '
  read TESTFLIGHT_API_TOKEN
fi

if [[ ! -z $TESTFLIGHT_API_TOKEN ]]; then
  travis encrypt "TESTFLIGHT_API_TOKEN='$TESTFLIGHT_API_TOKEN'" --add
fi

#
# TestFlight Team Token
#

if [[ -z $TESTFLIGHT_TEAM_TOKEN ]]; then
  echo '[TRAVIS]: Enter TestFlight Team token: '
  read TESTFLIGHT_TEAM_TOKEN
fi

if [[ ! -z $TESTFLIGHT_TEAM_TOKEN ]]; then
  travis encrypt "TESTFLIGHT_TEAM_TOKEN='$TESTFLIGHT_TEAM_TOKEN'" --add
fi

#
# Developer Password
#

if [[ -z $DEVELOPER_PASSWORD ]]; then
  echo '[TRAVIS]: Enter Apple Developer Password: '
  read -s DEVELOPER_PASSWORD
fi

if [[ ! -z $DEVELOPER_PASSWORD ]]; then
  travis encrypt "DEVELOPER_PASSWORD='$DEVELOPER_PASSWORD'" --add
fi

#
# Developer certificate password
#

if [[ -z $DEVELOPER_IDENTITY_PASSWORD ]]; then
  echo '[TRAVIS]: Enter Developer Certificate Password: '
  read -s DEVELOPER_IDENTITY_PASSWORD
fi

if [[ ! -z $DEVELOPER_IDENTITY_PASSWORD ]]; then
  travis encrypt "DEVELOPER_IDENTITY_PASSWORD='$DEVELOPER_IDENTITY_PASSWORD'" --add
fi

#
# HipChat Token
#

if [[ -z $HIPCHAT_TOKEN ]]; then
  echo '[TRAVIS]: Enter HipChat API Token: '
  read HIPCHAT_TOKEN
fi

if [[ ! -z $HIPCHAT_TOKEN ]]; then
  travis encrypt "HIPCHAT_TOKEN='$HIPCHAT_TOKEN'" --add
fi

#
# HipChat Room ID
#

if [[ -z $HIPCHAT_ROOM_ID ]]; then
  echo '[TRAVIS]: Enter HipChat Room: '
  read HIPCHAT_ROOM_ID
fi

if [[ ! -z $HIPCHAT_ROOM_ID ]]; then
  travis encrypt "HIPCHAT_ROOM_ID='$HIPCHAT_ROOM_ID'" --add
fi
