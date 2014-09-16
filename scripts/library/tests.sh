#!/bin/bash

# exit on failure
set -e

#
# Outputs reporter script location
#

run_tests()
{
  #
  # Fill defaults
  #

  if [[ -z $DIR_PATH ]]; then
    DIR_PATH=$(pwd)
  fi

  if [[ -z BUILD_CONFIG ]]; then
    BUILD_CONFIG='Release'
  fi

  #
  # Search for workspace if project and workspace not set
  #

  if [[ -z $WORKSPACE ]] && [[ -z $PROJECT ]]; then
    search_targets
  fi

  #
  # Check if we have workspace or project at least
  #
  if [[ -z $WORKSPACE ]] && [[ -z $PROJECT ]]; then
    message "test" "Nothing to test, aborting..." trace error
    exit 1
  fi

  set_build_path

  #
  # Load other parameters from the XCode itself
  #

  message "test" "Source path: $BUILD_PATH" trace normal


  # Remember previous dir
  CURRENT_DIR=$(pwd)
  cd $BUILD_PATH

  search_scheme

  cd $CURRENT_DIR

  #
  # Check for scheme
  #

  if [[ -z $SCHEME ]]; then
    message "test" "No scheme found in project (did you set it as shared?). Aborting..." warn error
    exit 1
  fi

  #
  # Build and test paths need to go under build directory, which is usually under .gitignore
  #

  TEST_PATH="$BUILD_PATH/build/test/"

  TEST_COMMAND=""

  if [[ ! -z $WORKSPACE ]]; then
    TEST_COMMAND="xctool -workspace $WORKSPACE"
  elif [[ ! -z $PROJECT ]]; then
    TEST_COMMAND="xctool -project $PROJECT"
  fi

  TEST_COMMAND=$TEST_COMMAND" -scheme $SCHEME -configuration $BUILD_CONFIG"

  #
  # Prepare commands
  #
  TEST_COMMAND=$TEST_COMMAND" CONFIGURATION_BUILD_DIR=$TEST_PATH"

  REPORTER=$(reporter);

  if [[ ! -z $REPORTER ]]; then
    TEST_COMMAND_REPORTER=$TEST_COMMAND" -reporter $REPORTER"
  else
    TEST_COMMAND_REPORTER=$TEST_COMMAND
  fi

  #
  # Check if we need to clean
  #

  TEST_CLEAN_COMMAND=$TEST_COMMAND" clean"
  
  execute_rake_test
  execute_test
}

execute_test()
{
  #
  # Executing built in Xcode tests...
  #

  if [[ ! -z $TEST_SDK ]]; then
    message "test" "Testing created build: $TEST_SDK" debug normal

    if [[ -d $TEST_PATH ]]; then
      message "test" "Test build already exists. Cleaning..." debug normal

      eval $TEST_CLEAN_COMMAND > /dev/null
    fi

    TEST_COMMAND=$TEST_COMMAND" test -sdk $TEST_SDK"
    TEST_COMMAND_REPORTER=$TEST_COMMAND_REPORTER" test -sdk $TEST_SDK"
    message "test" "Testing build..." debug normal

    #
    # Check for Rakefile, run rake test command, otherwise run xctool test
    #

    TEST_EXECUTE=`eval $TEST_COMMAND_REPORTER || true`

    message "test" $TEXT_EXECUTE trace normal

    NO_FAILURES=`echo $TEST_EXECUTE | grep ' 0 errored' | head -1`
    NO_ERRORS=`echo $TEST_EXECUTE | grep ' 0 failed' | head -1`

    TEST_EXECUTE=`echo $TEST_EXECUTE | sed -e 's/^ *//' -e 's/ *$//'`

    if [[ ! -z $NO_FAILURES ]] && [[ ! -z $NO_ERRORS ]]; then
      message "test" "Test complete: <b>$SCHEME</b> ($TEST_EXECUTE)" info success
    else
      message "test" "Test failed: <b>$SCHEME</b> ($TEST_EXECUTE)" info error

      eval $TEST_CLEAN_COMMAND > /dev/null
      eval $TEST_COMMAND

      exit 1
    fi
  fi
}

execute_rake_test()
{
  #
  # Testing, always run rake script, no matter the situation
  #

  RAKE_SCRIPT=`find . -name Rakefile | head -n1`

  if [[ -f $RAKE_SCRIPT ]]; then

    message "test" "Running Rake script..." debug normal

    $($RAKE_SCRIPT test)

    message "test" "Rake testing finished." trace normal
  fi
}