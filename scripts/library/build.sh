#!/bin/bash

# exit on failure
set -e


build()
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
    message "build" "Nothing to build, aborting..." trace error
    exit 1

  elif [[ ! -z $WORKSPACE ]]; then
    message "build" "Building Workspace: $WORKSPACE" debug normal
  elif [[ ! -z $PROJECT ]]; then
    message "build" "Building Project: $PROJECT" debug normal
  fi

  set_build_path

  #
  # Load other parameters from the XCode itself
  #

  message "build" "Source path: $BUILD_PATH" debug normal

  # Remember previous dir
  CURRENT_DIR=$(pwd)
  cd $BUILD_PATH

  search_scheme

  cd $CURRENT_DIR

  #
  # Check for scheme
  #

  if [[ -z $SCHEME ]]; then
    message "build" "No scheme found in project (did you set it as shared?). Aborting..." warn error
    exit 1
  fi

  #
  # Build and test paths need to go under build directory, which is usually under .gitignore
  #

  BUILD_PATH="$BUILD_PATH/build/app/"

  BUILD_COMMAND=""

  if [[ ! -z $WORKSPACE ]]; then
    BUILD_COMMAND="xctool -workspace $WORKSPACE"
  elif [[ ! -z $PROJECT ]]; then
    BUILD_COMMAND="xctool -project $PROJECT"
  fi

  BUILD_COMMAND=$BUILD_COMMAND" -scheme $SCHEME -configuration $BUILD_CONFIG"

  #
  # If we are building for simulator, do not care about provisioning
  #

  if [[ -z $PROFILE_UUID ]] && [[ $BUILD_SDK != *simulator* ]]; then
    find_profile $DEVELOPER_PROVISIONING
  fi

  #
  # Add profile build command
  #

  if [[ ! -z $PROFILE_UUID ]]; then
    message "build" "Searching profile UUID: $PROFILE_UUID" debug normal

    BUILD_COMMAND=$BUILD_COMMAND" PROVISIONING_PROFILE=$PROFILE_UUID"
  elif [[ $BUILD_SDK != *simulator* ]]; then
    message "build" "Could not find provisioning profile, continuing with default setting..." info warning
  fi

  #
  # Lets try to find the code sign identity by looking at our certificates in keychain.
  # Easier than getting to them from command line
  #

  if [[ -z $CODE_SIGN  ]] && [[ $BUILD_SDK != *simulator* ]]; then
    message "build" "No code signing identity specified.. Searching certificates..." debug warning

    CODE_SIGN=$(find_signing_identity)

    message "build" "Found identity: $CODE_SIGN" trace normal
  fi

  if [[ ! -z $CODE_SIGN ]] && [[ $BUILD_SDK != *simulator* ]]; then
    message "build" "Using developer identity: <b>$CODE_SIGN</b>" info success

    BUILD_COMMAND=$BUILD_COMMAND" CODE_SIGN_IDENTITY=$CODE_SIGN"
  elif [[ $BUILD_SDK != *simulator* ]]; then
    message "build" "No code signing identity found. Building with default..." warn warning
  fi

  #
  # Prepare commands
  #
  BUILD_COMMAND=$BUILD_COMMAND" CONFIGURATION_BUILD_DIR=$BUILD_PATH"

  REPORTER=$(reporter);

  if [[ ! -z $REPORTER ]]; then
    BUILD_COMMAND_REPORTER=$BUILD_COMMAND" -reporter $REPORTER"
  else
    BUILD_COMMAND_REPORTER=$BUILD_COMMAND
  fi

  #
  # Build number
  #

  if [[ ! -z $BUILD_NUMBER ]]; then
    set_build_number $BUILD_NUMBER $ADD_BUILD_NUMBER_TO_PROJECT
  fi

  #
  # Check if we need to clean
  #

  BUILD_CLEAN_COMMAND=$BUILD_COMMAND" clean"

  if [[ -d $BUILD_PATH ]]; then
    message "build" "Build already exists. Cleaning..." trace normal

    eval $BUILD_CLEAN_COMMAND > /dev/null

    message "build" "Build clean finished." trace success
  fi

  #
  # Run build command
  #

  BUILD_COMMAND=$BUILD_COMMAND" build -sdk $BUILD_SDK"
  BUILD_COMMAND_REPORTER=$BUILD_COMMAND_REPORTER" build -sdk $BUILD_SDK"

  message "build" "Building project with xctool..." trace normal

  execute_build
}

set_build_path()
{
  #
  # Print what are we building
  #

  if [[ ! -z $WORKSPACE ]]; then
    BUILD_PATH=$(dirname $WORKSPACE)
  fi

  if [[ ! -z $PROJECT ]]; then
    BUILD_PATH=$(dirname $PROJECT)
  fi
}

search_scheme()
{
  # Bash to split by newline character
  IFS=$'\n'

  SCHEMES=()
  TARGETS=()
  CONFIGURATIONS=()

  PARSE_TYPE=0

  for line in $(xcodebuild -list);
  do
    #
    # First see what parsing mode are we in
    #
    if [[ $line == *Schemes:* ]]; then
      PARSE_TYPE=1
    elif [[ $line == *Targets:* ]]; then
      PARSE_TYPE=2
    elif [[ $line == *Configurations:* ]]; then
    PARSE_TYPE=3
  elif [ $(echo $line | grep 'build configuration') ]; then
    PARSE_TYPE=0
  elif [ "$PARSE_TYPE" != 0 ]; then
    # Trim line
    CURRENT_LINE=$(echo $line | tr -d '[[:space:]]')

#echo $CURRENT_LINE

    if [[ -z $CURRENT_LINE ]]; then
#echo 'RESETTING...'

      PARSE_TYPE=0
    elif [ "$PARSE_TYPE" = 1 ]; then
#echo 'Scheme: '$CURRENT_LINE

      SCHEMES+=($CURRENT_LINE)

      if [[ -z $SCHEME ]]; then
        SCHEME=$CURRENT_LINE
      fi
    elif [ "$PARSE_TYPE" = 2 ]; then
#echo 'Target: '$CURRENT_LINE

      TARGETS+=($CURRENT_LINE)
    elif [ "$PARSE_TYPE" = 3 ]; then
#echo 'Configuration: '$CURRENT_LINE

      CONFIGURATIONS+=($CURRENT_LINE)

      if [[ -z $BUILD_CONFIG ]]; then
        BUILD_CONFIG=$CURRENT_LINE
      fi
    fi
  fi
  done
}

set_build_number()
{
  #
  # Find project PLIST, by using scheme name (which is usually the same)
  #

  IFS=$'\n'

  for filename in $(find . -iname $SCHEME-Info.plist);
  do

    #
    # If we should add build number to project's build number, need to read projects
    # build number.
    #

    BUILD_NUMBER=$1

    if [ "$2" = true ]; then
      message "build" "Reading project build number..." trace normal

      PROJECT_BUILD_NUMBER=$(read_property $filename CFBundleVersion)

      BUILD_NUMBER=$((PROJECT_BUILD_NUMBER + BUILD_NUMBER))

      message "build" "Project build numbers set from: $PROJECT_BUILD_NUMBER to $BUILD_NUMBER" debug normal
    fi

    message "build" "Setting build number to: $BUILD_NUMBER" debug normal

    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" $filename
    break
  done
}

execute_build()
{

  #
  # Allow the subshell to exit, as we are manually checking for errors
  #

  message "build" "Build command: $BUILD_COMMAND"

  BUILD_EXECUTE=`eval $BUILD_COMMAND_REPORTER || true`
  #echo $BUILD_COMMAND_REPORTER

  message "build" "Building complete." trace normal

  #
  # Check the build status
  #

  NO_ERRORS=`echo $BUILD_EXECUTE | grep ' 0 errors' | head -1`
  NO_WARNINGS=`echo $BUILD_EXECUTE | grep ' 0 warnings' | head -1`

  BUILD_EXECUTE=`echo $BUILD_EXECUTE | sed -e 's/^ *//' -e 's/ *$//'`

  #
  # Find built .app file, check for successful build
  #

  APP_PATH=$(find_dir '*.app')

  if [[ -z $APP_PATH ]]; then
    NO_ERRORS=''
    NO_WARNINGS=''
  fi

  #
  # Build succeeded if there are no warnings or we allow warnings
  #
  if [[ ! -z $NO_ERRORS ]] && ([[ ! -z $NO_WARNINGS ]] || [ "$DEPLOY_ALLOW_WARNING_BUILDS" = true ]); then
    if [[ ! -z $NO_WARNINGS ]]; then
      message "build" "Build completed (<b>$BUILD_SDK</b>): <b>$SCHEME</b> ($BUILD_EXECUTE)" info success
    else
      message "build" "Build completed with warnings (<b>$BUILD_SDK</b>): <b>$SCHEME</b> ($BUILD_EXECUTE)" info warning
    fi
  else
    if [[ ! -z $NO_ERRORS ]] && [ "$DEPLOY_ALLOW_WARNING_BUILDS" = false ]; then
      message "build" "Build failed - <b>warnings not allowed</b> (<b>$BUILD_SDK</b>): <b>$SCHEME</b> ($BUILD_EXECUTE)" warn error
    else
      message "build" "Build failed (<b>$BUILD_SDK</b>): <b>$SCHEME</b> ($BUILD_EXECUTE)" warn error
    fi

    #
    # Rerun build script with normal formatter, so we get a nice, clean output with exact error,
    # But first we must clean, to make sure all warnings appear correctly
    #

    eval $BUILD_CLEAN_COMMAND > /dev/null

    LOG_REPORT_PATH=$(create_report_path build $BUILD_SDK)

    `eval $BUILD_COMMAND -reporter plain:"./report/"$LOG_REPORT_PATH"_build_xcode.log" || true`

    cat './report/'$LOG_REPORT_PATH'_build_xcode.log'

    exit 1
  fi
}

#
# Outputs reporter script location
#

reporter()
{
  REPORTER_SCRIPT=`find . -name reporter.rb | head -n1`

  IFS=$'\n'

  if [[ -f $REPORTER_SCRIPT ]]; then
    echo $REPORTER_SCRIPT
  fi
}

search_targets()
{
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
}

create_report_path()
{
  LOG_REPORT_PATH=''

  if [[ ! -z $1 ]]; then
    LOG_REPORT_PATH="$1"
  fi

  if [[ ! -z $2 ]]; then
    LOG_REPORT_PATH=$LOG_REPORT_PATH'_'"$2"
  fi

  if [[ ! -z $TRAVIS_JOB_NUMBER ]]; then
    LOG_REPORT_PATH=$TRAVIS_JOB_NUMBER'_'$LOG_REPORT_PATH
  fi

  echo $LOG_REPORT_PATH
}