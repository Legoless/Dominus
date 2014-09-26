#!/bin/bash

report()
{
  if [ "$REPORT" = true ] && [ -d './report' ]; then
    message "report" "Collecting generated reports..." trace normal

    collect_reports
  else
    message "report" "Skipping report collection." info warning
  fi
}

#
# Private functions
#

collect_reports()
{
  #
  # Construct correct report directory
  #  

  #ARTIFACTS_GEM=$(gem list travis-artifacts -i)

  #if [ "$ARTIFACTS_GEM" == "false"]; then
  #  message "report" "Installing artifacts gem..." debug normal

  #	gem_install "travis-artifacts"
  #fi

  message "report" "Preparing path to upload reports..." trace normal

  #
  # Create result path to where on server we will store reports
  #

  RESULT_PATH=$(create_result_path)
  RESULT_PATH=$RESULT_PATH'reports/'

  message "report" "Report upload target path: $RESULT_PATH" debug normal

  #
  # Scan through report directory and upload all files
  #

  message "report" "Scanning report directory for log files..." debug normal

  for f in $(find ./report);
  do
  	if [ -f $f ]; then
      message "report" "Uploading report file: $f" trace normal

  	  upload_log $RESULT_PATH $f
  	fi
  done
}

create_result_path()
{
  RESULT_PATH='iOS/'

  if [[ ! -z $TRAVIS_BRANCH ]]; then
  	RESULT_PATH=$RESULT_PATH"$TRAVIS_BRANCH/"
  fi

  PROPERTY_LIST=$(find_property_list)

  if [[ ! -z $PROPERTY_LIST ]]; then
    APP_VERSION=$(read_property $PROPERTY_LIST CFBundleShortVersionString)

    RESULT_PATH=$RESULT_PATH"$APP_VERSION/"
  fi

  CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")

  RESULT_PATH=$RESULT_PATH"$CURRENT_DATE"

  if [[ ! -z $TRAVIS_COMMIT ]]; then
  	RESULT_PATH=$RESULT_PATH"_$TRAVIS_COMMIT"
  fi

  if [[ ! -z $TRAVIS_BUILD_NUMBER ]]; then
  	RESULT_PATH=$RESULT_PATH"_$TRAVIS_BUILD_NUMBER"
  fi

  RESULT_PATH=$RESULT_PATH'/'

  echo "$RESULT_PATH"
}

upload_log()
{
  upload_amazon $1 $2
}

upload_amazon()
{
  if [[ ! -z $ARTIFACTS_S3_BUCKET ]] && [[ ! -z $ARTIFACTS_AWS_ACCESS_KEY_ID ]] && [[ ! -z $ARTIFACTS_AWS_SECRET_ACCESS_KEY ]]; then
    travis-artifacts upload --target-path $1 --path $2
  fi
}