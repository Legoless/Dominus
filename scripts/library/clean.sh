#!/bin/bash

clean()
{
  set +e

  message "clean" "Cleaning integration files..." debug normal

  #security delete-keychain ios-build.keychain
  #rm -f ~/Library/MobileDevice/Provisioning\ Profiles/*
  delete_dir ./build

  delete_dir ./report

  delete_file $AWSCLI_CONFIG_FILENAME

  delete_file 'awscli_config.yml'

  set -e
}

delete_file()
{
  if [ -f $1 ]; then
    rm $1
  fi
}

delete_dir()
{
  if [ -d $1 ]; then
    rm -rf $1
  fi
}