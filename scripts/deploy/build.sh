#!/bin/bash

# exit on failure
set -e

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
# Script usage
#
usage()
{
cat << EOF
Usage: $0 <options>

This script will search for .xcworkspace file and use first shared scheme, unless specified. If no .xcworkspace file exists, the script will search for .xcodeproj file and use any scheme available there.

OPTIONS:
   -h                  Show this message
   -d <directory>      Specific project directory (default: .)
   -w <workspace>      Specific workspace
   -p <project>        Specific project
   -s <scheme>         Specific scheme
   -c <config>         Build Configuration (default: Debug)
   -k <sdk>            Build SDK
   -f <profile>        Provisioning profile to sign executable
   -n <identity>       Code Sign Identity
   -b <build>          Desired build number
   -t <test>           Testing SDK
   -a                  Allow building with warnings
EOF
}

DIR_PATH=""
WORKSPACE=""
PROJECT=""
SCHEME=""
BUILD_CONFIG=""
SDK=""
PROFILE=""
CODE_SIGN=""
BUILD_NUMBER=""
TEST_SDK=""
ALLOW_WARNINGS=false

while getopts “h:d:w:p:s:c:k:f:n:b:t:a” OPTION; do
  case $OPTION in
    h) usage; exit 1;;
    d) DIR_PATH=$OPTARG;;
    w) WORKSPACE=$OPTARG;;
    p) PROJECT=$OPTARG;;
    s) SCHEME=$OPTARG;;
    c) BUILD_CONFIG=$OPTARG;;
    k) SDK=$OPTARG;;
    f) PROFILE=$OPTARG;;
    n) CODE_SIGN=$OPTARG;;
    b) BUILD_NUMBER=$OPTARG;;
    t) TEST_SDK=$OPTARG;;
    a) ALLOW_WARNINGS=true;;
    [?]) usage; exit;;
  esac
done

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
  message "Nothing to build, aborting..." warn error

  echo '[BUILD]: Nothing to build, aborting...'
  exit 1
fi

#
# Print what are we building
#

if [[ ! -z $WORKSPACE ]]; then
  message "Building Workspace: $WORKSPACE" debug normal

  echo '[BUILD]: Building Workspace:' $WORKSPACE
  BUILD_PATH=$(dirname $WORKSPACE)
fi

if [[ ! -z $PROJECT ]]; then
  message "Building Project: $PROJECT" debug normal

  echo '[BUILD]: Building project:' $PROJECT
  BUILD_PATH=$(dirname $PROJECT)
fi

#
# Load other parameters from the XCode itself
#

echo '[BUILD]: Source path:' $BUILD_PATH

# Remember previous dir
CURRENT_DIR=$(pwd)
cd $BUILD_PATH

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
done;

cd $CURRENT_DIR

#echo $CURRENT_DIR

#
# Check for scheme
#
if [[ -z $SCHEME ]]; then
  message "No scheme found in project. Aborting..." warn error

  echo '[BUILD]: No scheme found in project (did you set it as shared?). Aborting...'
  exit 1
fi

if [[ -z BUILD_CONFIG ]]; then
  BUILD_CONFIG='Release'
fi

#
# Build and test paths need to go under build directory, which is usually under .gitignore
#

TEST_PATH="$BUILD_PATH/build/test/"
BUILD_PATH="$BUILD_PATH/build/app/"

BUILD_COMMAND=""

if [[ ! -z $WORKSPACE ]]; then
  BUILD_COMMAND="xctool -workspace $WORKSPACE"
elif [[ ! -z $PROJECT ]]; then
  BUILD_COMMAND="xctool -project $PROJECT"
fi

BUILD_COMMAND=$BUILD_COMMAND" -scheme $SCHEME -configuration $BUILD_CONFIG"

#
# Find provisioning profile UUID from existing provisioning profiles and check with name,
# but we need to have a developer provisioning name.
#

PROFILE_UUID=""

#
# If no profile specified, use developer provisioning global profile
#

if [[ ! -z $PROFILE ]]; then
  message "Searching correct profile: $PROFILE" debug normal

  echo '[BUILD]: Searching for profile:' $PROFILE

  OUTPUT="$HOME/Library/MobileDevice/Provisioning Profiles/"

  for filename in $(find $OUTPUT -iname *.mobileprovision);
  do

    PROFILE_NAME=`grep "<key>Name</key" -A1 -a $filename`
    PROFILE_NAME=${PROFILE_NAME##*<string>}
    PROFILE_NAME=${PROFILE_NAME%%</string>*}

    if [[ -f $filename ]] && [ "$PROFILE" == "$PROFILE_NAME" ]; then
      echo '[BUILD]: Found profile:' $PROFILE_NAME

      PROFILE_UUID=${filename%%.*}
      PROFILE_UUID=${PROFILE_UUID##*/}
      break
    fi
  done
fi

#
# Add profile build command
#

if [[ ! -z $PROFILE_UUID ]]; then
  message "Searching profile UUID: $PROFILE_UUID" debug normal

  echo '[BUILD]: Selected profile UUID:' $PROFILE_UUID

  BUILD_COMMAND=$BUILD_COMMAND" PROVISIONING_PROFILE=$PROFILE_UUID"
else
  message "Could not find provisioning profile, continuing with default setting..." info warning

  echo '[BUILD]: Could not find provisioning profile, continuing with default setting...'
fi

#
# Lets try to find the code sign identity by looking at our certificates in keychain.
# Easier than getting to them from command line
#

if [[ -z $CODE_SIGN  ]]; then
  message "No code signing identity specified.. Searching certificates..." debug warning

  echo '[BUILD]: No code signing identity specified.. Searching certificates...'

  #IDENTITIES=$(security find-identity -v ~/Library/Keychains/ios-build.keychain | grep "iPhone" | head -n1)
  IDENTITY=`security find-identity -v | grep "iPhone" | head -n1`
  IDENTITY=${IDENTITY##*iPhone}
  IDENTITY=${IDENTITY%%\"*}
  IDENTITY="\"iPhone$IDENTITY\""

  echo '[BUILD]: Found identity:' $IDENTITY

  CODE_SIGN=$IDENTITY
fi

if [[ ! -z $CODE_SIGN ]]; then
  message "Using developer identity: <b>$IDENTITY</b>" info success

  BUILD_COMMAND=$BUILD_COMMAND" CODE_SIGN_IDENTITY=$CODE_SIGN"
else
  message "No code signing identity found. Building with default..." warn warning

  echo '[BUILD]: No code signing identity found. Building with default...'
fi

# Prepare commands

TEST_COMMAND=$BUILD_COMMAND" CONFIGURATION_BUILD_DIR=$TEST_PATH"
BUILD_COMMAND=$BUILD_COMMAND" CONFIGURATION_BUILD_DIR=$BUILD_PATH"

REPORTER=$(reporter);

if [[ ! -z $REPORTER ]]; then
  BUILD_COMMAND_REPORTER=$BUILD_COMMAND" -reporter $REPORTER"
  TEST_COMMAND_REPORTER=$TEST_COMMAND" -reporter $REPORTER"
else
  BUILD_COMMAND_REPORTER=$BUILD_COMMAND
  TEST_COMMAND_REPORTER=$TEST_COMMAND
fi

#
# Sort out build number
#

if [[ ! -z $BUILD_NUMBER ]]; then

  #
  # Find project PLIST, by using scheme name (which is usually the same)
  #

  IFS=$'\n'

  for filename in $(find . -iname $SCHEME-Info.plist);
  do
    message "Setting build number to: $BUILD_NUMBER" debug normal

    echo '[BUILD]: Setting build number to:' $BUILD_NUMBER

    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" $filename
    break
  done
fi

#
# Check if we need to clean
#

BUILD_CLEAN_COMMAND=$BUILD_COMMAND" clean"
TEST_CLEAN_COMMAND=$TEST_COMMAND" clean"

if [[ -d $BUILD_PATH ]]; then
  echo '[BUILD]: Build already exists. Cleaning...'

  eval $BUILD_CLEAN_COMMAND > /dev/null
fi

#
# Run build command
#

BUILD_COMMAND=$BUILD_COMMAND" build"
BUILD_COMMAND_REPORTER=$BUILD_COMMAND_REPORTER" build"

BUILD_EXECUTE=`eval $BUILD_COMMAND_REPORTER`

#
# Check the build status
#

NO_ERRORS=`echo $BUILD_EXECUTE | grep ' 0 errors' | head -1`
NO_WARNINGS=`echo $BUILD_EXECUTE | grep ' 0 warnings' | head -1`

BUILD_EXECUTE=`echo $BUILD_EXECUTE | sed -e 's/^ *//' -e 's/ *$//'`

#
# Build succeeded if there are no warnings or we allow warnings
#
if [[ ! -z $NO_ERRORS ]] && ([[ ! -z $NO_WARNINGS ]] || [ "$ALLOW_WARNINGS" = true ]); then
  if [[ ! -z $NO_WARNINGS ]]; then
    message "Build completed: <b>$SCHEME</b> ($BUILD_EXECUTE)" info success
  else
    message "Build completed with warnings: <b>$SCHEME</b> ($BUILD_EXECUTE)" info warning
  fi

  echo '[BUILD]: Build completed:' $SCHEME '('$BUILD_EXECUTE')'
else
  if [[ ! -z $NO_ERRORS ]] && [ "$ALLOW_WARNINGS" = false ]; then
    message "Build failed (<b>warnings not allowed</b>): <b>$SCHEME</b> ($BUILD_EXECUTE)" warn error
  else
    message "Build failed: <b>$SCHEME</b> ($BUILD_EXECUTE)" warn error
  fi

  echo '[BUILD]: Build failed:' $SCHEME '('$BUILD_EXECUTE')'

  #
  # Rerun build script with normal formatter, so we get a nice, clean output with exact error,
  # But first we must clean, to make sure all warnings appear correctly
  #

  eval $BUILD_CLEAN_COMMAND > /dev/null
  eval $BUILD_COMMAND

  exit 1
fi

#
# Testing, always run rake script, no matter the situation
#

RAKE_SCRIPT=`find . -name Rakefile | head -n1`

if [[ -f $RAKE_SCRIPT ]]; then
  echo '[BUILD]: Running Rake script...'

  message "Running Rake script..." debug normal

  $($RAKE_SCRIPT test)

  echo '[BUILD]: Rake testing finished.'
fi

#
# Executing built in Xcode tests...
#

if [[ ! -z $TEST_SDK ]]; then
  echo '[BUILD]: Testing created build...'

  if [[ -d $TEST_PATH ]]; then
    echo '[BUILD]: Test build already exists. Cleaning...'

    eval $TEST_CLEAN_COMMAND > /dev/null
  fi

  TEST_COMMAND=$TEST_COMMAND" test -sdk $TEST_SDK"
  TEST_COMMAND_REPORTER=$TEST_COMMAND_REPORTER" test -sdk $TEST_SDK"
  message "Testing build..." debug normal

  #
  # Check for Rakefile, run rake test command, otherwise run xctool test
  #

  TEST_EXECUTE=`eval $TEST_COMMAND_REPORTER || true`

  NO_FAILURES=`echo $TEST_EXECUTE | grep ' 0 errored' | head -1`
  NO_ERRORS=`echo $TEST_EXECUTE | grep ' 0 failed' | head -1`

  TEST_EXECUTE=`echo $TEST_EXECUTE | sed -e 's/^ *//' -e 's/ *$//'`

  if [[ ! -z $NO_FAILURES ]] && [[ ! -z $NO_ERRORS ]]; then
    echo '[BUILD]: Test complete:' $SCHEME '('$TEST_EXECUTE')'
    message "Test complete: <b>$SCHEME</b> ($TEST_EXECUTE)" info success
  else
    echo '[BUILD]: Test failed:' $SCHEME '('$TEST_EXECUTE')'
    message "Test failed: <b>$SCHEME</b> ($TEST_EXECUTE)" info error

    eval $TEST_CLEAN_COMMAND > /dev/null
    eval $TEST_COMMAND

    exit 1
  fi

fi
