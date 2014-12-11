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
  echo 'script:' >> .travis.yml
  echo '- ./Dominus/dominus.sh integrate' >> .travis.yml
  echo 'after_failure:' >> .travis.yml
  echo '- ./Dominus/dominus.sh integrate report' >> .travis.yml
  echo 'env:' >> .travis.yml
  echo '  matrix:' >> .travis.yml
  echo '  - SDK=8.0 ACTION=deploy' >> .travis.yml
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
# -----------------------------------------------------------------------
#

#
# Global variables
#

if [[ -z $PLATFORM ]]; then
  echo '[PROJECT]: Enter platform for project (iphone): '
  read PLATFORM
fi

if [[ ! -z $PLATFORM ]]; then
  writecfg "PLATFORM" "$PLATFORM"
else
  writecfg "PLATFORM" "iphone"
fi

if [[ -z $LOG_LEVEL ]]; then
  echo '[PROJECT]: Enter notification log level [warn|info|debug]: '
  read LOG_LEVEL
fi

if [[ ! -z $LOG_LEVEL ]]; then
  writecfg "LOG_LEVEL" "$LOG_LEVEL"
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
# Warning builds
#

if [[ -z $DEPLOY_ALLOW_WARNING_BUILDS ]]; then
  echo '[PROJECT]: Allow warning builds to be deployed (true/false): '
  read DEPLOY_ALLOW_WARNING_BUILDS
fi

if [[ ! -z $ALLOWS_WARNING_BUILDS ]]; then
  writecfg "DEPLOY_ALLOW_WARNING_BUILDS" "$DEPLOY_ALLOW_WARNING_BUILDS"
else
  writecfg "DEPLOY_ALLOW_WARNING_BUILDS" "false"
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
# Updating devices
#

if [[ -z $DEPLOY_UPDATE_DEVICES ]]; then
  echo '[PROJECT]: Should device UDIDs be updated from TestFlight (true/false)? '
  read DEPLOY_UPDATE_DEVICES
fi

if [[ ! -z $DEPLOY_UPDATE_DEVICES ]]; then
  writecfg "DEPLOY_UPDATE_DEVICES" "$DEPLOY_UPDATE_DEVICES"
else
  writecfg "DEPLOY_UPDATE_DEVICES" "false"
fi

#
# Deploy
#

if [[ -z $DEPLOY_WAIT_FOR_OTHER_JOBS ]]; then
  echo '[PROJECT]: Should deploy action wait for other jobs to complete (true/false)? '
  read DEPLOY_WAIT_FOR_OTHER_JOBS
fi

if [[ ! -z $DEPLOY_WAIT_FOR_OTHER_JOBS ]]; then
  writecfg "DEPLOY_WAIT_FOR_OTHER_JOBS" "$DEPLOY_WAIT_FOR_OTHER_JOBS"
else
  writecfg "DEPLOY_WAIT_FOR_OTHER_JOBS" "true"
fi

#
# -----------------------------------------------------------------------
#

if [[ -z $FAUXPAS_LICENSE_KEY ]]; then
  echo '[PROJECT]: Would you like to prepare Faux Pas Quality Check tool (y/n)? '
  read FAUXPAS_INSTALL

  if [ "$FAUXPAS_INSTALL" = "y" ]; then
    if [[ -z $FAUXPAS_LICENSE_TYPE ]]; then
      echo '[PROJECT]: Faux Pas License Type (organization-seat/personal)? '
      read FAUXPAS_LICENSE_TYPE
    fi

    if [[ -z $FAUXPAS_LICENSE_NAME ]]; then
      echo '[PROJECT]: Faux Pas License Name: '
      read FAUXPAS_LICENSE_TYPE
    fi

    if [[ -z $FAUXPAS_LICENSE_KEY ]]; then
      echo '[PROJECT]: Faux Pas License Key: '
      read FAUXPAS_LICENSE_KEY
    fi
  fi
fi

if [[ ! -z $FAUXPAS_LICENSE_TYPE ]]; then
  writecfg "FAUXPAS_LICENSE_TYPE" "$FAUXPAS_LICENSE_TYPE"
fi

if [[ ! -z $FAUXPAS_LICENSE_NAME ]]; then
  writecfg "FAUXPAS_LICENSE_NAME" "$FAUXPAS_LICENSE_NAME"
fi

#
# -----------------------------------------------------------------------
#

if [[ -z $TESTFLIGHT_TEAM ]]; then
  echo '[PROJECT]: Would you like to setup TestFlight Access (y/n)? '
  read TESTFLIGHT_INSTALL

  if [ "$TESTFLIGHT_INSTALL" = "y" ]; then
    if [[ -z $FAUXPAS_LICENSE_TYPE ]]; then
      echo '[PROJECT]: Faux Pas License Type (organization-seat/personal)? '
      read FAUXPAS_LICENSE_TYPE
    fi

    if [[ -z $FAUXPAS_LICENSE_NAME ]]; then
      echo '[PROJECT]: Faux Pas License Name: '
      read FAUXPAS_LICENSE_TYPE
    fi

    if [[ -z $FAUXPAS_LICENSE_KEY ]]; then
      echo '[PROJECT]: Faux Pas License Key: '
      read FAUXPAS_LICENSE_KEY
    fi
  fi
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


if [[ -z $TESTFLIGHT_API_TOKEN ]]; then
  echo '[PROJECT]: Enter TestFlight API token: '
  read TESTFLIGHT_API_TOKEN
fi


#
# TestFlight Password
#

if [[ -z $TESTFLIGHT_PASSWORD ]]; then
  echo '[PROJECT]: Enter TestFlight Password: '
  read -s TESTFLIGHT_PASSWORD
fi

#
# TestFlight Team Token
#

if [[ -z $TESTFLIGHT_TEAM_TOKEN ]]; then
  echo '[PROJECT]: Enter TestFlight Team token: '
  read TESTFLIGHT_TEAM_TOKEN
fi

#
# -----------------------------------------------------------------------
#

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


if [[ ! -z $TESTFLIGHT_PASSWORD ]]; then
  writecfg "TESTFLIGHT_PASSWORD" "$TESTFLIGHT_PASSWORD" "secure"
fi

#
# TestFlight API Token
#


if [[ ! -z $TESTFLIGHT_API_TOKEN ]]; then
  writecfg "TESTFLIGHT_API_TOKEN" "$TESTFLIGHT_API_TOKEN" "secure"
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

if [[ ! -z $FAUXPAS_LICENSE_KEY ]]; then
  writecfg "FAUXPAS_LICENSE_KEY" "$FAUXPAS_LICENSE_KEY" "secure"
fi

