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

  if [[ ! -z $TEST_CLEAN_COMMAND ]]; then
    #
    # Clean test files
    #

    eval $TEST_CLEAN_COMMAND > /dev/null
  fi

  PROFILE=$DEVELOPER_PROVISIONING

  message "send" "Sending build to distribution service..." debug normal

  #
  # Find provisioning profile
  #

  if [[ $BUILD_SDK != *simulator* ]]; then
    find_profile
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

  BUILD_PATH="$BUILD_PATH/build"

  if [ ! -d "$BUILD_PATH" ]; then
    message "send" "Project build folder does not exist yet. Aborting..." warn error

    exit 1
  fi

  #
  # Find built .app file
  #

  APP_PATH=$(find_dir '*.app')
  ARCHIVE_PATH=$(find_dir '*.xcarchive')

  if [[ ! -z $APP_PATH ]]; then
    APP_NAME=$(basename $APP_PATH)
    APP_NAME=${APP_NAME%.*}
  fi

  message "send" "Using .app at: $APP_PATH, name: $APP_NAME" trace normal

  if [[ ! -z $ARCHIVE_PATH ]]; then
    message "send" "Using Archive at $ARCHIVE_PATH" trace normal
  fi

  RELEASE_NOTES=$(construct_release_notes $APP_PATH)

  #
  # Search for all installed developer identities
  #

  if [[ $BUILD_SDK != *simulator* ]]; then
    message "send" "Searching developer identities..." debug normal

    #
    # We must find ALL developer identities in provisioning profile, so we can sign with one that is correct.
    # First get the developer keys base64 code from provisioning profile.
    #

    if [[ -z $PROFILE_FILE ]]; then
      find_profile $DEVELOPER_PROVISIONING
    fi

    KEYS=`strings $PROFILE_FILE | sed -n "/<data>/,/<\/data>/p" | tr -d '\n'`

    DEVELOPER_KEYS=()

    while [[ $KEYS == *\<data\>* ]]
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

    if [ -f $APP_PATH ]; then

      #
      # Sign and package
      #

      message "send" "Building $APP_NAME.ipa with $IDENTITY..." debug normal
      xcrun -sdk iphoneos PackageApplication "$APP_PATH" -o "$BUILD_PATH/$APP_NAME.ipa" -sign "$IDENTITY" -embed "$PROFILE_FILE"

      message "send" "Creating dSYM symbol ZIP package..." trace normal

      package "$APP_PATH.dSYM"
    else
      message "send" "Could not find $APP_PATH, aborting..." warn error

      exit 1
    fi
  else
    message "send" "Creating iOS Simulator ZIP package..." trace normal

    package "$APP_PATH"

    message "send" "iOS Simulator package created at: $BUILD_PATH/$APP_NAME.app.zip" trace normal
  fi

  #
  # Add release notes
  #

  if [[ -z $RELEASE_NOTES ]]; then
    RELEASE_NOTES="$APP_NAME Automated Build"
  fi

  #
  # Upload to some where
  #

  RESULT_PATH=$(create_result_path)
  RESULT_PATH=$RESULT_PATH'binary/'

  #
  # Check if we are to wait for other jobs to finish before deploying. This only works on CI.
  # We need both the flag and GitHub Token and Travis Build ID and Repo Slug for this.
  # Start ruby script if possible.
  #

  if ([[ -z $DEPLOY_WAIT_FOR_OTHER_JOBS ]] || [ "$DEPLOY_WAIT_FOR_OTHER_JOBS" == true ]) && [[ ! -z $GITHUB_TOKEN ]] && [[ ! -z $TRAVIS_BUILD_ID ]] && [[ ! -z $TRAVIS_REPO_SLUG ]]; then
    WORKER_SCRIPT=$(worker_script)
    WAIT_RESULT=$($WORKER_SCRIPT $TRAVIS_REPO_SLUG $TRAVIS_BUILD_ID $GITHUB_TOKEN)

    message "send" "$WAIT_RESULT" debug normal

    if [[ $WAIT_RESULT == *"Failed"* ]]; then
      message "send" "One of the tests failed. Aborting deployment..." warn error
      exit 1
    fi
  fi

  #
  # Write release notes to a report file
  #

  RELEASE_NOTES_REPORT_PATH=$(write_release_notes)

  if [[ $BUILD_SDK != *simulator* ]]; then
    message "send" "Uploading package to TestFlight..." debug normal

    upload_testflight
    upload_hockeyapp
    upload_deploygate
    upload_fir
    upload_itunes
    upload_crashlytics

    upload_file $RESULT_PATH "$BUILD_PATH/$APP_NAME.ipa"
    upload_file $RESULT_PATH "$APP_PATH.dSYM.zip"
    upload_file $RESULT_PATH "$ARCHIVE_PATH"
  else
    message "send" "Deploy complete. <b>$APPNAME</b> was successfully uploaded." warn success

    upload_file $RESULT_PATH "$APP_PATH.zip"
  fi
}

upload_hockeyapp()
{
  if [[ ! -z $HOCKEY_API_TOKEN ]]; then
    gem_install "shenzhen"

    local DISTRIBUTE_COMMAND="ipa distribute:hockeyapp -a $HOCKEY_API_TOKEN -f $BUILD_PATH/$APP_NAME.ipa -d $APP_PATH.dSYM.zip"

    if [[ ! -z $RELEASE_NOTES ]]; then
      DISTRIBUTE_COMMAND=$DISTRIBUTE_COMMAND` -m "$RELEASE_NOTES"`
    fi

    if [[ ! -z $HOCKEY_DISTRIBUTION_LIST ]]; then
      DISTRIBUTE_COMMAND=$DISTRIBUTE_COMMAND" --tags $HOCKEY_DISTRIBUTION_LIST"
    fi

    local DISTRIBUTE_OUTPUT=`eval $DISTRIBUTE_COMMAND`

    message "send" "$DISTRIBUTE_OUTPUT" trace normal

    message "send" "Deploy complete. <b>$APPNAME</b> was distributed to HockeyApp <b>$HOCKEY_DISTRIBUTION_LIST</b>." warn success
  else
    message "send" "Skipping HockeyApp deployment, missing token information." debug warning
  fi
}

upload_deploygate()
{
  if [[ ! -z $DEPLOYGATE_API_TOKEN ]] && [[ ! -z $DEPLOYGATE_USERNAME ]]; then
    gem_install "shenzhen"

    local DISTRIBUTE_COMMAND="ipa distribute:deploygate -a $DEPLOYGATE_API_TOKEN -u $DEPLOYGATE_USERNAME -f $BUILD_PATH/$APP_NAME.ipa -d"

    if [[ ! -z $RELEASE_NOTES ]]; then
      DISTRIBUTE_COMMAND=$DISTRIBUTE_COMMAND` -m "$RELEASE_NOTES"`
    fi

    local DISTRIBUTE_OUTPUT=`eval $DISTRIBUTE_COMMAND`

    message "send" "$DISTRIBUTE_OUTPUT" trace normal

    message "send" "Deploy complete. <b>$APPNAME</b> was distributed to DeployGate <b>$HOCKEY_DISTRIBUTION_LIST</b>." warn success
  else
    message "send" "Skipping DeployGate deployment, missing account information." debug warning
  fi
}

upload_fir()
{
  if [[ ! -z $FIR_USER_TOKEN ]] && [[ ! -z $FIR_APP_ID ]]; then
    gem_install "shenzhen"

    local DISTRIBUTE_COMMAND="ipa distribute:fir -a $FIR_APP_ID -u $FIR_USER_TOKEN -f $BUILD_PATH/$APP_NAME.ipa"

    if [[ ! -z $RELEASE_NOTES ]]; then
      DISTRIBUTE_COMMAND=$DISTRIBUTE_COMMAND` -n "$RELEASE_NOTES"`
    fi

    local DISTRIBUTE_OUTPUT=`eval $DISTRIBUTE_COMMAND`

    message "send" "$DISTRIBUTE_OUTPUT" trace normal

    message "send" "Deploy complete. <b>$APPNAME</b> was distributed to Fly It Remotely." warn success
  else
    message "send" "Skipping Fly It Remotely deployment, missing account information." debug warning
  fi
}

upload_itunes()
{
  if [[ ! -z $ITUNES_USERNAME ]] && [[ ! -z $ITUNES_PASSWORD ]] && [[ ! -z $ITUNES_APP_ID ]]; then
    gem_install "shenzhen"

    local DISTRIBUTE_COMMAND="ipa distribute:itunesconnect -a $ITUNES_USERNAME -p $ITUNES_PASSWORD -i $ITUNES_APP_ID -f $BUILD_PATH/$APP_NAME.ipa"

    local DISTRIBUTE_OUTPUT=`eval $DISTRIBUTE_COMMAND`

    message "send" "$DISTRIBUTE_OUTPUT" trace normal

    message "send" "Deploy complete. <b>$APPNAME</b> was distributed to iTunes Connect." warn success
  else
    message "send" "Skipping iTunes Connect deployment, missing account information." debug warning
  fi
}

upload_testflight()
{
  if [[ ! -z $TESTFLIGHT_API_TOKEN ]] && [[ ! -z $TESTFLIGHT_TEAM_TOKEN ]]; then
    gem_install "shenzhen"

    local DISTRIBUTE_COMMAND="ipa distribute:testflight -a $TESTFLIGHT_API_TOKEN -T $TESTFLIGHT_TEAM_TOKEN -f $BUILD_PATH/$APP_NAME.ipa -d $APP_PATH.dSYM.zip"

    if [[ ! -z $RELEASE_NOTES ]]; then
      DISTRIBUTE_COMMAND=$DISTRIBUTE_COMMAND` -m "$RELEASE_NOTES"`
    fi

    if [[ ! -z $TESTFLIGHT_DISTRIBUTION_LIST ]]; then
      DISTRIBUTE_COMMAND=$DISTRIBUTE_COMMAND" -l $TESTFLIGHT_DISTRIBUTION_LIST"
    fi

    local DISTRIBUTE_OUTPUT=`eval $DISTRIBUTE_COMMAND`

    message "send" "$DISTRIBUTE_OUTPUT" trace normal

    message "send" "Deploy complete. <b>$APPNAME</b> was distributed to TestFlight <b>$TESTFLIGHT_DISTRIBUTION_LIST</b>." warn success
  else
    message "send" "Skipping TestFlight deployment, missing token information." debug warning
  fi
}

upload_crashlytics()
{
  if [[ ! -z $CRASHLYTICS_API_TOKEN ]] && [[ ! -z $CRASHLYTICS_BUILD_TOKEN ]]; then
    CRASHLYTICS_FRAMEWORK=$(find_dir Crashlytics.framework)

    if [[ -z $CRASHLYTICS_FRAMEWORK ]]; then
      message "send" "Cannot locate Crashlytics framework. Aborting." info error
    fi

    local DISTRIBUTE_COMMAND=$CRASHLYTICS_FRAMEWORK'/submit '$CRASHLYTICS_API_TOKEN' '$CRASHLYTICS_BUILD_TOKEN' -ipaPath '$BUILD_PATH'/'$APP_NAME'.ipa'

    #
    # Check for release notes report path
    #
    
    if [[ ! -z $RELEASE_NOTES_REPORT_PATH ]]; then
      DISTRIBUTE_COMMAND=$CRASHLYTICS_COMMAND' -notesPath '$RELEASE_NOTES_REPORT_PATH
    fi

    #
    # Check for group aliases
    #

    if [[ ! -z $CRASHLYTICS_DISTRIBUTION_LIST ]]; then
      DISTRIBUTE_COMMAND=$DISTRIBUTE_COMMAND' -groupAliases '$CRASHLYTICS_DISTRIBUTION_LIST
    fi

    local DISTRIBUTE_OUTPUT=`eval $DISTRIBUTE_COMMAND`

    message "send" "$DISTRIBUTE_OUTPUT" trace normal

    message "send" "Deploy complete. <b>$APPNAME</b> was distributed to Crashlytics <b>$CRASHLYTICS_DISTRIBUTION_LIST</b>." warn success
  else
    message "send" "Skipping Crashlytics deployment, missing token information." debug warning
  fi
}

write_release_notes()
{
  if [[ ! -z $RELEASE_NOTES ]]; then
    RELEASE_NOTES_REPORT_PATH=$(create_report_path)

    RELEASE_NOTES_REPORT_PATH='./report/'$RELEASE_NOTES_REPORT_PATH'_release_notes.txt'

    echo "$RELEASE_NOTES" > "$RELEASE_NOTES_REPORT_PATH"

    echo $RELEASE_NOTES_REPORT_PATH
  fi
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

    RELEASE_NOTES="$PROJECT_NAME"
  fi

  #
  # Find a correct property list, based on App Path, because we are looking for a compiled property list
  #

  if [[ ! -z $1 ]]; then
    PROPERTY_LIST=$(find_property_list $1)
  else
  	PROPERTY_LIST=$(find_property_list)
  fi

  #
  # Append version and build to release notes
  #

  if [[ ! -z $PROPERTY_LIST ]]; then

    APP_VERSION=$(read_property $PROPERTY_LIST CFBundleShortVersionString)

    #
    # Override bundle name here if we have it
    #

    BUNDLE_NAME=$(read_property $PROPERTY_LIST CFBundleDisplayName)

    if [[ ! -z $BUNDLE_NAME ]] && [[ "$BUNDLE_NAME" != *PRODUCT_NAME* ]]; then
      RELEASE_NOTES=$BUNDLE_NAME
    fi

    RELEASE_NOTES="$RELEASE_NOTES (v$APP_VERSION"

    PLIST_BUILD_NUMBER=$(read_property $PROPERTY_LIST CFBundleVersion)
    RELEASE_NOTES=$RELEASE_NOTES'.'$PLIST_BUILD_NUMBER

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
    RELEASE_NOTES=$RELEASE_NOTES' Automated Build (Branch: '$BUILD_BRANCH').'
  else
    RELEASE_NOTES=$RELEASE_NOTES' Automated Build.'
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

  echo "$RELEASE_NOTES"
}

find_property_list()
{
  # Find a correct property list
  PROPERTY_LIST=''

  local TARGET_DIR='.'

  if [[ ! -z $1 ]]; then
    TARGET_DIR=$1
  fi

  for filename in $(find $TARGET_DIR -iname *Info.plist -maxdepth 2);
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

worker_script()
{
  REPORTER_SCRIPT=`find . -name travis_wait.rb | head -n1`

  IFS=$'\n'

  if [[ -f $REPORTER_SCRIPT ]]; then
    echo $REPORTER_SCRIPT
  fi
}
