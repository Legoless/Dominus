#!/bin/bash

find_scheme()
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

find_bundle_identifier()
{
  #
  # Try to read Bundle Identifier from Property Info list.
  #
  TARGET_PROPERTY_LIST=$(find_property_list)

  if [[ ! -z $TARGET_PROPERTY_LIST ]]; then

    local READ_BUNDLE_IDENTIFIER=$(read_property $TARGET_PROPERTY_LIST CFBundleIdentifier)

    #
    # Certain new projects have a reference here, try to load it from project pbxproj file.
    # Alternative would be to load it from .xcconfig files
    #

    if [[ $READ_BUNDLE_IDENTIFIER == *"$"* ]] && [[ ! -z $PROJECT ]]; then
      PROJECT_PBXPROJ=$(find_project_pbxproj $PROJECT)

      READ_BUNDLE_IDENTIFIER=$(find_project_setting $PROJECT_PBXPROJ 'BUNDLE_IDENTIFIER')
    fi

    echo $READ_BUNDLE_IDENTIFIER
  fi
}

find_project_setting()
{
  #echo grep -F '"'$2'"' $1 | head -n 1

  local PROJECT_SETTING=$(grep -F $2 $1 | head -n 1)

  #
  # Remove everything before equal sign
  #

  PROJECT_SETTING=${PROJECT_SETTING#*=}

  #
  # Remove everything after the semicolon
  #

  PROJECT_SETTING=${PROJECT_SETTING%;}
  PROJECT_SETTING=$(trim $PROJECT_SETTING)
  
  echo $PROJECT_SETTING
}

#
# Finds project pbxproj file
#
find_project_pbxproj()
{
  echo "$1/project.pbxproj"
}

find_xcode_targets()
{
  SEARCH_PATH=$(find_search_path $1)

  if [[ -z $WORKSPACE ]]; then
    WORKSPACE=$(find_workspace $SEARCH_PATH)
  fi

  if [[ -z $PROJECT ]]; then
    PROJECT=$(find_project $SEARCH_PATH)
  fi

  #export WORKSPACE=$WORKSPACE
  #export PROJECT=$PROJECT
}

find_search_path ()
{
  local SEARCH_PATH=$1

  if [[ -z $SEARCH_PATH ]]; then
    SEARCH_PATH=$DIR_PATH
  fi

  if [[ -z $SEARCH_PATH ]]; then
    SEARCH_PATH='.'
  fi

  echo $SEARCH_PATH
}

find_workspace()
{
  local SEARCH_PATH=$(find_search_path $1)

  for f in $(find $SEARCH_PATH -iname *.xcworkspace);
  do
    if [[ -d $f ]] && [[ $f != */project.xcworkspace ]]; then
      PROJECT_WORKSPACE=$f
    fi
  done

  echo $PROJECT_WORKSPACE
}

find_project()
{
  local SEARCH_PATH=$(find_search_path $1)

  for f in $(find $SEARCH_PATH -iname *.xcodeproj -maxdepth 2);
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