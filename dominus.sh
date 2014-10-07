#!/bin/bash

# UTF-8
export LANG=en_US.UTF-8

# exit on failure
set -e

#
# Load all functions from library and utilities
#

load()
{
  for filename in $(find . -iname '*.sh' -path "*/utility/*");
  do
    source $filename
  done

  for filename in $(find . -iname '*.sh' -path "*/library/*");
  do
    source $filename
  done
}

#
# Update
#

update()
{
  echo '[DOMINUS]: Updating scripts in' $SCRIPT_PATH

  #
  # Find Dominus.sh script
  #

  DOMINUS_SCRIPT=`find . -name dominus.sh | head -n1`

  if [[ ! -f $DOMINUS_SCRIPT ]]; then
    echo '[DOMINUS]: Running myself, but no script:' $DOMINUS_SCRIPT 'Aborting...'

    exit 1;
  fi

  #
  # Get directory of Dominus script and attempt to up
  #

  DOMINUS_DIR=`dirname $DOMINUS_SCRIPT`

  if [[ -f $DOMINUS_DIR'/.git' ]]; then
    echo '[DOMINUS]: Found Dominus .git repository. Updating...'

    PREVIOUS_DIR=`pwd`

    cd $DOMINUS_DIR
    git pull origin master
    cd $PREVIOUS_DIR

    echo '[DOMINUS]: Successfully updated Dominus code from GitHub.'

  else
    echo '[DOMINUS]: Cannot find Dominus .git repository:' $DOMINUS_DIR'/.git, unable to update. Skipping...'
  fi
}

#
# Setup
#

setup()
{
  case "$1" in
    environment) environment;;
    project) project;;
    travis) travis;;
    certificate) certificate;;
    *) help_setup
    exit 1
    ;;
  esac
}

#
# Integrate
#

integrate()
{
  #
  # Store action as global
  #

  if [[ ! -z $1 ]]; then
    ACTION=$1
  fi

  if [[ -z $ACTION ]]; then
    ACTION='build'
  fi

  if [ "$ACTION" == "test" ]; then
    ACTION='run_tests'
  fi

  #
  # Create build and test SDK's if both sdk and platform are specified
  #
  
  if [[ ! -z $SDK ]] && [[ ! -z $PLATFORM ]]; then
    
    if [ "$PLATFORM" == "iphone" ]; then

      if [ "$ACTION" != "run_tests" ]; then
        BUILD_SDK=$PLATFORM'os'
        BUILD_SDK=$BUILD_SDK"$SDK"
      fi

      TEST_SDK=$PLATFORM'simulator'
    else
      BUILD_SDK=$PLATFORM"$SDK"
      TEST_SDK=$PLATFORM"$SDK"
    fi
  fi

  export BUILD_SDK=$BUILD_SDK
  export TEST_SDK=$TEST_SDK

  #
  # Init and library is always run on CI, since it always starts
  # from point 0
  #

  if [ "$CI" = true ] && [ "$ACTION" != "report" ]; then
    init
    #library
  fi

  #
  # Define actions
  #

  case "$ACTION" in
    init) init;;
    library) library;;
    build) provision;
    cert;
    project_build;;
    run_tests) run_tests;;
    quality) quality;;
    report) report;;
    deploy) provision;
    cert;
    project_build;
    send;;
    send) send;;
    *) exit 1;;
  esac

  #
  # Finalize report and clean
  #

  if [ "$ACTION" != "report" ]; then
    report
  fi

  clean
}

#
# Environment
#

environment()
{
  if [[ -f $SCRIPT_PATH'setup/environment.sh' ]]; then
    $SCRIPT_PATH'setup/environment.sh'
  else
    echo '[DOMINUS]: Unable to find 'environment' script. Try to run' \"$0 update\"'.'
    exit 1
  fi
}

#
# Project
#

project()
{
  if [[ -f $SCRIPT_PATH'setup/project.sh' ]]; then
    $SCRIPT_PATH'setup/project.sh' -c
  else
    echo '[DOMINUS]: Unable to find 'project' script. Try to run' \"$0 update\"'.'
    exit 1
  fi
}

#
# Travis
#

travis()
{
  if [[ -f $SCRIPT_PATH'setup/project.sh' ]]; then
    $SCRIPT_PATH'setup/project.sh' -t
  else
    echo '[DOMINUS]: Unable to find 'project' script. Try to run' \"$0 update\"'.'
    exit 1
  fi
}

#
# Certificate
#

certificate()
{
  echo '[DOMINUS]: Certificate Not implemented'
}

#
# Build project
#

project_build()
{
    #
    # Add Travis CI build number to building
    #

    PROFILE=$DEVELOPER_PROVISIONING

    if [ "$DEPLOY_USE_BUILD_NUMBER" == "travis" ] && [[ ! -z $TRAVIS_BUILD_NUMBER ]]; then
      BUILD_NUMBER=$TRAVIS_BUILD_NUMBER
    elif [ "$DEPLOY_USE_BUILD_NUMBER" == "project" ] && [[ ! -z $TRAVIS_BUILD_NUMBER ]]; then
      BUILD_NUMBER=$TRAVIS_BUILD_NUMBER
      ADD_BUILD_NUMBER_TO_PROJECT=true
    fi

    build
}

#
# Global settings
#

VARIABLE_PATH='./dominus.cfg'
ATLANTIS_PATH='testflight'
CUPERTINO_PATH='iospro'

#
# Search for correct script path
#
SCRIPT_PATH=`find . -name dominus.sh | head -n1`
SCRIPT_PATH=$(dirname ${SCRIPT_PATH})
SCRIPT_PATH=$SCRIPT_PATH'/scripts/'

SCRIPT_VERSION='0.5.1'

#
# Load all utility functions
#

load

#
# Load environment variables from file, if it exists, otherwise they should be loaded
# in environment by CI itself, to make it secure.
#

set -a

if [ -f $VARIABLE_PATH ]; then
  test -f $VARIABLE_PATH && . $VARIABLE_PATH
fi

set +a

#set -o

#
# Check if there was any command provided, otherwise display usage
#

case "$1" in
  help) help_usage;;
  version) version;;
  update) update;;
  setup) setup $2;;
  integrate) integrate $2;;
  *) help_usage
  exit 1
  ;;
esac