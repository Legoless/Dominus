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
  # If scan file exists, we run it and run the report
  #

  local SCAN_FILE=$(find_file 'report.junit')

  if [[ ! -z $SCAN_FILE ]]; then
  	install_scan

  	set +e

  	`scan`

	set -e

	test_report

  	return
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
  elif [[ ! -z $WORKSPACE ]]; then
    message "test" "Testing Workspace: $WORKSPACE" debug normal
  elif [[ ! -z $PROJECT ]]; then
    message "test" "Testing Project: $PROJECT" debug normal
  fi

  set_build_path

  #
  # Load other parameters from the XCode itself
  #

  message "test" "Source path: $BUILD_PATH" trace normal

  select_scheme

  #
  # Check for scheme
  #

  if [[ -z $SCHEME ]]; then
    message "test" "No scheme found in project (did you set it as shared?). Aborting..." warn error
    exit 1
  fi

  #
  # Load config from scheme file on Test action
  #

  BUILD_CONFIG=$(find_config $SCHEME_FILE Test)

  #
  # Install Scan
  #

  install_scan

  #
  # Build and test paths need to go under build directory, which is usually under .gitignore
  #

  TEST_PATH="$BUILD_PATH/build/test/"

  TEST_COMMAND=""

  if [[ ! -z $WORKSPACE ]]; then
    TEST_COMMAND="scan --workspace $WORKSPACE"
  elif [[ ! -z $PROJECT ]]; then
    TEST_COMMAND="scan --project $PROJECT"
  fi

  TEST_COMMAND=$TEST_COMMAND" --scheme $SCHEME"

  if [[ ! -z $TEST_DEVICE ]]; then
  	TEST_COMMAND=$TEST_COMMAND" --device '$TEST_DEVICE'"
  fi

  #
  # Append build configuration
  #

  if [[ ! -z $BUILD_CONFIG ]]; then
    message "test" "Using Test Action build config in scheme: $BUILD_CONFIG" debug normal

    TEST_COMMAND=$TEST_COMMAND" --configuration $BUILD_CONFIG"
  else
    message "test" "Build configuration not detected, using xcodebuild..." info warning
  fi

  setup_bootstrap
  
  execute_test
}

execute_test()
{
  #
  # Executing built in Xcode tests...
  #

  if [[ ! -z $TEST_SDK ]]; then

    if [[ -d $TEST_PATH ]]; then
      message "test" "Test build already exists. Adding clean parameter..." debug normal

      TEXT_COMMAND=$TEST_COMMAND" --clean"
    fi

    message "test" "Testing build: $TEST_SDK" debug normal

    TEST_COMMAND=$TEST_COMMAND" --sdk $TEST_SDK --verbose"

    #if [[ ! -z $BUILD_SDK ]]; then
    #  TEST_COMMAND=$TEST_COMMAND" --sdk $BUILD_SDK"
    #fi



	#if [[ $TEST_SDK == *simulator* ]]; then
	#  TEST_COMMAND=$TEST_COMMAND" -arch i386"
	#fi

	#
	# Prepare commands
	#
	#TEST_COMMAND=$TEST_COMMAND" --xcargs CONFIGURATION_BUILD_DIR=\"$TEST_PATH\""

	#if [[ $TEST_SDK == *simulator* ]]; then
	#  TEST_COMMAND=$TEST_COMMAND" VALID_ARCHS='i386'"
	#fi

    #
    # Code Coverage requires link to the project, try to find it
    #

    if [[ -z $PROJECT ]]; then
      PROJECT=$(find_project)
    fi

    if [ "$GENERATE_CODE_COVERAGE" == true ] && [[ ! -z $PROJECT ]]; then
      message "test" "Setuping project for Code Coverage: $PROJECT" info normal

      gem_install "slather"

      slather setup $PROJECT
    fi

    message "test" "Test command: $TEST_COMMAND" trace normal

    #
    # Run tests
    #

    set +e

    eval $TEST_COMMAND

    set -e

    test_report
  fi
}

test_report()
{
  #
  # Parsing Test Result from generaten JUnit XML file
  #

  local TEST_REPORT_FILE=$(find_file 'report.junit')

  if [[ ! -z $TEST_REPORT_FILE ]]; then

    #local TEST_RESULT=`cat $TEST_REPORT_FILE | grep "<testsuites tests=" | head -1`

    local TESTS_RUN=$(xmllint --noblanks --xpath "string(//testsuites/@tests)" $TEST_REPORT_FILE)
	local TESTS_FAILED=$(xmllint --noblanks --xpath "string(//testsuites/@failures)" $TEST_REPORT_FILE)

    if [ "$TESTS_FAILED" == "0" ]; then
      message "test" "Test complete (<b>$TEST_SDK</b>): <b>$SCHEME</b> (Run: <b>$TESTS_RUN</b> Failed: <b>$TESTS_FAILED</b>)" warn success

      generate_code_coverage

    else
      message "test" "Test failed (<b>$TEST_SDK</b>): <b>$SCHEME</b> (Run: <b>$TESTS_RUN</b> Failed: <b>$TESTS_FAILED</b>)" warn error

      generate_code_coverage

      #echo $TEST_COMMAND

      #eval $TEST_CLEAN_COMMAND > /dev/null

      #LOG_REPORT_PATH=$(create_report_path tests $TEST_SDK)

      #eval $TEST_COMMAND' -reporter junit:./report/'$LOG_REPORT_PATH'.xml' > './report/'$LOG_REPORT_PATH'_xcode.log'
      #`eval $TEST_COMMAND -reporter plain:"./report/"$LOG_REPORT_PATH"_test_xcode.log" || true`
      #eval $TEST_COMMAND

      #cat './report/'$LOG_REPORT_PATH'_test_xcode.log'
      
      exit 1
    fi
  else
  	message "test" "Test failed (<b>$TEST_SDK</b>): <b>$SCHEME</b> (<b>Build Errored</b>)" warn success
  	exit 1
  fi
}

install_slather ()
{
	SPECIFIC_INSTALL_GEM=$(check_gem specific_install)

    #
    # Check for awscli gem which is needed for 
    #

    if [ "$SPECIFIC_INSTALL_GEM" == "false" ]; then
      gem_install "specific_install"
	  
	  #gem specific_install -l https://github.com/viteinfinite/slather -b feature-profdata
    fi

    gem specific_install -l https://github.com/legoless/slather -b feature-profdata
}

install_scan ()
{
	SPECIFIC_INSTALL_GEM=$(check_gem specific_install)

    #
    # Check for awscli gem which is needed for 
    #

    if [ "$SPECIFIC_INSTALL_GEM" == "false" ]; then
      gem_install "specific_install"
    fi

    gem specific_install -l https://github.com/legoless/scan
}

generate_code_coverage()
{
  #
  # Slather knows how to upload to certain services, but only if configuration file is defined.
  #

  SLATHER_FILE=$(find_file '.slather.yml')

  set +e

  if [[ ! -z $SLATHER_FILE ]]; then
    message "test" "Detected Slather file, running code coverage upload..." trace normal
    
    install_slather

    #echo '\n' >> $SLATHER_FILE
    #echo 'build_directory: '$TEST_PATH >> $SLATHER_FILE
    #find /users/travis -iname "*.profdata" 

	#find /users/travis -iname "*.profdata" -exec cat {} +

	#find /users/travis -iname "*.gcno"

    #cat $SLATHER_FILE

    slather

    message "test" "Slather upload finished." debug success
  fi

  if [ "$GENERATE_CODE_COVERAGE" == true ] && [[ ! -z $PROJECT ]]; then
    gem_install "slather"

    message "test" "Generating Code Coverage for: $PROJECT" trace normal

    slather coverage --html $PROJECT

    message "test" "Code Coverage report generated." debug success
  fi

  set -e
}