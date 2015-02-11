#!/bin/bash

report()
{
  if [ "$REPORT" == true ] && [ -d './report' ]; then
    message "report" "Collecting generated reports..." trace normal

    upload_prepare

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

  	  upload_file $RESULT_PATH $f
  	fi
  done
}

create_result_path()
{
  RESULT_PATH=''

  #
  # Project name
  #

  if [[ ! -z $CI_REPOSITORY ]] && [ "$REPORT_USE_REPOSITORY_NAME" != false ]; then
    REPO_SLUG=$(clean_repository_name $CI_REPOSITORY)
    REPO_SLUG=$(echo $REPO_SLUG | tr '[:upper:]' '[:lower:]')
    RESULT_PATH="$REPO_SLUG/"
  fi

  RESULT_PATH=$RESULT_PATH"ios/"

  if [[ ! -z $CI_BRANCH ]]; then
  	RESULT_PATH=$RESULT_PATH"$CI_BRANCH/"
  fi

  PROPERTY_LIST=$(find_property_list)

  #
  # App version
  #

  if [[ ! -z $PROPERTY_LIST ]]; then
    APP_VERSION=$(read_property $PROPERTY_LIST CFBundleShortVersionString)

    RESULT_PATH=$RESULT_PATH"$APP_VERSION/"
  fi

  #
  # Date
  #

  CURRENT_DATE=$(date +"%Y-%m-%d")

  RESULT_PATH=$RESULT_PATH"$CURRENT_DATE/"

  if [[ ! -z $CI_COMMIT ]]; then
    #
    # CI Build Number
    #

    if [[ ! -z $CI_BUILD_NUMBER ]]; then
      RESULT_PATH=$RESULT_PATH'Build_'$CI_BUILD_NUMBER
    fi

    COMMIT_HASH=${CI_COMMIT:0:8}

  	RESULT_PATH=$RESULT_PATH'_'$COMMIT_HASH

    RESULT_PATH=$RESULT_PATH'/'
  fi

  echo "$RESULT_PATH"
}

upload_file()
{
  if [ -f $2 ]; then
    upload_amazon $1 $2
  fi
}

upload_amazon()
{
  if [[ ! -z $ARTIFACTS_S3_BUCKET ]] && [[ ! -z $ARTIFACTS_AWS_ACCESS_KEY_ID ]] && [[ ! -z $ARTIFACTS_AWS_SECRET_ACCESS_KEY ]]; then

    set +e

    if [[ ! -z $ARTIFACTS_S3_REGION ]]; then
      awscli s3 files put -b $ARTIFACTS_S3_BUCKET -p $2 -d $1 --region $ARTIFACTS_S3_REGION
    else
      awscli s3 files put -b $ARTIFACTS_S3_BUCKET -p $2 -d $1
    fi

    set -e
    
  fi
}

upload_prepare()
{
  if [[ -z $AWSCLI_CONFIG_FILE ]]; then
    AWSCLI_CONFIG_FILENAME='awscli_config.yml'

    #
    # Construct correct report directory
    #

    ARTIFACTS_GEM=$(check_gem awscli)

    #
    # Check for awscli gem which is needed for 
    #

    if [ "$ARTIFACTS_GEM" == "false" ]; then
      message "report" "Installing awscli gem..." debug normal

    	gem_install "awscli"
    fi

    #
    # Sort out config file
    #

    if [ ! -f $AWSCLI_CONFIG_FILENAME ]; then
      message "report" "Writing awscli config file..." debug normal

      echo "aws_access_key_id: $ARTIFACTS_AWS_ACCESS_KEY_ID" > awscli_config.yml
      echo "aws_secret_access_key: $ARTIFACTS_AWS_SECRET_ACCESS_KEY" >> awscli_config.yml
    fi

    if [[ -z $AWSCLI_CONFIG_FILE ]]; then
      export AWSCLI_CONFIG_FILE=$AWSCLI_CONFIG_FILENAME
    fi
  fi
}