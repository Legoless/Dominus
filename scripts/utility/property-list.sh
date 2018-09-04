#!/bin/bash

# exit on failure
set -e

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

find_property_list()
{
  # Find a correct property list
  PROPERTY_LIST=''

  local TARGET_DIR='.'

  if [[ ! -z $1 ]]; then
    TARGET_DIR=$1
  fi

  for filename in $(find $TARGET_DIR -iname "*Info.plist" -maxdepth 5);
  do

    #
    # Select property list if it does not contain Tests or Pods
    #

    if [[ ! $filename == *Tests* ]] && [[ ! $filename == *Pods* ]] && [[ ! $filename == *.storyboard* ]]; then
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