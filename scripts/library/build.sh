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

  select_scheme

  #
  # Check for scheme
  #

  if [[ -z $SCHEME ]]; then
    message "build" "No scheme found in project (did you set at least one scheme as shared?). Aborting..." warn error
    exit 1
  fi

  #
  # Load config from scheme file on Launch action
  #

  BUILD_CONFIG=$(find_config $SCHEME_FILE Launch)

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

  BUILD_COMMAND=$BUILD_COMMAND" -scheme $SCHEME"

  #
  # Append build configuration
  #

  if [[ ! -z $BUILD_CONFIG ]]; then
    message "build" "Using Launch Action build config in scheme: $BUILD_CONFIG" debug normal

    BUILD_COMMAND=$BUILD_COMMAND" -configuration $BUILD_CONFIG"
  else
    message "build" "Build configuration not detected, using xcodebuild..." info warning
  fi

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

    BUILD_COMMAND=$BUILD_COMMAND" CODE_SIGN_IDENTITY=\"$CODE_SIGN\""
  elif [[ $BUILD_SDK != *simulator* ]]; then
    message "build" "No code signing identity found. Building with default..." warn warning
  fi

  #
  # Prepare commands
  #
  BUILD_COMMAND=$BUILD_COMMAND" CONFIGURATION_BUILD_DIR=$BUILD_PATH"

  #
  # Build number
  #

  if [[ ! -z $BUILD_NUMBER ]]; then
    message "build" "Updating build number with: $BUILD_NUMBER" debug normal

    find_target $SCHEME_FILE

    set_build_number $BUILD_NUMBER $ADD_BUILD_NUMBER_TO_PROJECT
  fi

  #
  # Check if we need to clean
  #

  BUILD_CLEAN_COMMAND=$BUILD_COMMAND" clean"

  if [[ -d $BUILD_PATH ]]; then
    message "build" "Build already exists. Cleaning..." trace normal

    rm -rf $BUILD_PATH

    eval $BUILD_CLEAN_COMMAND > /dev/null
    message "build" "Build clean finished." trace success
  fi

  #
  # Run build command
  #

  if [[ ! -z $BUILD_SDK ]]; then
    BUILD_COMMAND=$BUILD_COMMAND" -sdk $BUILD_SDK"
  fi

  setup_bootstrap

  message "build" "Building project with xctool..." trace normal

  execute_command "$BUILD_COMMAND build"

  #
  # Find built .app file, check for successful build
  #

  APP_PATH=$(find_dir '*.app')
  
  if [[ $BUILD_SDK != *simulator* ]] && [ "$BUILD_ARCHIVE" = true ]; then
    message "build" "Archiving project with xctool..." trace normal

    ARCHIVE_NAME=$(archive_name $SCHEME)
    ARCHIVE_COMMAND=$BUILD_COMMAND" archive -archivePath \"$BUILD_PATH/$ARCHIVE_NAME.xcarchive\""

    execute_command "$ARCHIVE_COMMAND"
  fi
}

archive_name()
{
  local ARCHIVE_TIME=$(date +"%d-%m-%y %H.%M")

  local ARCHIVE_NAME=$1" "$ARCHIVE_TIME

  echo $ARCHIVE_NAME
}

setup_bootstrap()
{
  #
  # Check if KZBootstrap exists in project and generate own user macros
  #

  ENVIRONMENTS=`find . -iname KZBEnvironments.plist | head -n1`

  IFS=$'\n'

  if [[ -f $ENVIRONMENTS ]]; then

    BOOTSTRAP=$(dirname ${ENVIRONMENTS})

    if [[ ! -f "$BOOTSTRAP/KZBootstrapUserMacros.h" ]]; then
      message "build" "Creating KZBootstrapUserMacros.h before building..." trace normal

      touch "$BOOTSTRAP/KZBootstrapUserMacros.h"
    fi
  fi
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

select_scheme()
{
  #
  # Search all schemes
  #

  if [[ ! -z $SCHEME ]]; then
    TARGET_SCHEME_FILE=$SCHEME
  fi

  for filename in $(find . -iname "*.xcscheme" ! -iname "Pods*");
  do
    #
    # If we have a scheme set, we need to find scheme file
    #

    SCHEME_BASENAME=$(basename $filename)
    SCHEME_BASENAME=${SCHEME_BASENAME%.*}

    if [[ ! -z $TARGET_SCHEME_FILE ]] && [ "$SCHEME_BASENAME" == "$TARGET_SCHEME_FILE" ]; then
      SCHEME_FILE=$filename

      break
    elif [ "$SCHEME_BASENAME" != "Quality" ] && [[ -z $SCHEME ]]; then
      SCHEME=$SCHEME_BASENAME
      SCHEME_FILE=$filename

      break
    fi

  done
}

set_build_number()
{
  #
  # Find project PLIST, by using scheme name (which is usually the same)
  #

  IFS=$'\n'

  message "build" "Searching for target property list: $TARGET" debug normal

  for filename in $(find . -iname "$TARGET*Info.plist" ! -iname "*Tests*");
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

execute_command()
{

  #
  # Allow the subshell to exit, as we are manually checking for errors
  #

  REPORTER_COMMAND=$(reporter_command $1)

  message "build" "Build command: $1" trace normal
  message "build" "Build reporter command: $REPORTER_COMMAND" trace normal

  BUILD_EXECUTE=`eval $REPORTER_COMMAND || true`

  message "build" "Building complete." trace normal

  #
  # Check the build status
  #

  NO_ERRORS=`echo $BUILD_EXECUTE | grep ' 0 errors' | head -1`
  NO_WARNINGS=`echo $BUILD_EXECUTE | grep ' 0 warnings' | head -1`

  BUILD_EXECUTE=`echo $BUILD_EXECUTE | sed -e 's/^ *//' -e 's/ *$//'`
  BUILD_EXECUTE=$(trim $BUILD_EXECUTE)

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

    `eval $1 -reporter plain:"./report/"$LOG_REPORT_PATH"_build_xcode.log" || true`

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

#
# Sets reporter command
#

reporter_command()
{
  REPORTER=$(reporter);

  local BUILD_COMMAND_REPORTER=$1

  if [[ ! -z $REPORTER ]]; then
    BUILD_COMMAND_REPORTER=$BUILD_COMMAND_REPORTER" -reporter $REPORTER"
  fi

  echo $BUILD_COMMAND_REPORTER
}

search_targets()
{
  if [[ -z $1 ]]; then
    SEARCH_PATH=$DIR_PATH
  fi

  if [[ -z $SEARCH_PATH ]]; then
    SEARCH_PATH='.'
  fi

  WORKSPACE=$(find_workspace $SEARCH_PATH)

  #
  # Search for project, but only if no workspace was found
  #

  if [[ -z $WORKSPACE ]]; then
    PROJECT=$(find_project $SEARCH_PATH)
  fi
}

find_workspace()
{
  for f in $(find $1 -iname *.xcworkspace);
  do
    if [[ -d $f ]] && [[ $f != */project.xcworkspace ]]; then
      PROJECT_WORKSPACE=$f
    fi
  done

  echo $PROJECT_WORKSPACE
}

find_project()
{
  for f in $(find $1 -iname *.xcodeproj -maxdepth 2);
  do
    if [[ -d $f ]] && [[ $f != *Pods* ]] && [[ $f != *pods* ]]; then
      PROJECT_FILE=$f
    fi
  done

  echo $PROJECT_FILE
}

find_config()
{
  SCHEME_ACTION=$2

  if [[ ! -z $BUILD_ACTION ]]; then
    SCHEME_ACTION='Launch'
  fi

  BUILD_CONFIG=$(xmllint $1 --xpath "string(//${SCHEME_ACTION}Action/@buildConfiguration)")

  echo $BUILD_CONFIG
}

find_target()
{
  #
  # If target is already specified, use it, otherwise look for one that is not a testing target
  #
  if [[ ! -z $TARGET ]]; then
    return
  fi

  TARGET_EXECUTABLE=$(xmllint $1 --xpath "string(//BuildAction/*/*/BuildableReference/@BuildableName)")

  # Remove .app if it is in target
  TARGET=${TARGET_EXECUTABLE%.*}
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

clean_repository_name()
{
  local REPOSITORY_NAME=$1

  #
  # Cut away organization from repo slug
  #
  REPOSITORY_NAME=${REPOSITORY_NAME#*/}

  #
  # Cut away App on the end and iOS
  #

  REPOSITORY_NAME=${REPOSITORY_NAME%App}
  REPOSITORY_NAME=${REPOSITORY_NAME%-iOS}
  REPOSITORY_NAME=${REPOSITORY_NAME%iOS}
  
  echo $REPOSITORY_NAME
}
