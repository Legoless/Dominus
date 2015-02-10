#!/bin/bash

#
# Loads Travis CI Environment variables
#
load_travis_environment()
{
  if [ "$TRAVIS" = false ]; then
  	return 0
  fi

  message "init" "Loading Travis Environment..." debug normal

  export CI_BUILD=true
  export CI_USER=$USER
  export CI_BRANCH=$TRAVIS_BRANCH
  export CI_BUILD_DIR=$TRAVIS_BUILD_DIR
  export CI_BUILD_ID=$TRAVIS_BUILD_ID
  export CI_BUILD_NUMBER=$TRAVIS_BUILD_NUMBER
  export CI_COMMIT=$TRAVIS_COMMIT
  export CI_COMMIT_RANGE=$TRAVIS_COMMIT_RANGE
  export CI_JOB_ID=$TRAVIS_JOB_ID
  export CI_JOB_NUMBER=$TRAVIS_JOB_NUMBER
  export CI_PULL_REQUEST=$TRAVIS_PULL_REQUEST
  export CI_REPOSITORY=$TRAVIS_REPO_SLUG
  export CI_TAG=$TRAVIS_TAG
}
