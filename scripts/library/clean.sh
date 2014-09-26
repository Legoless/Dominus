#!/bin/bash

clean()
{
  message "clean" "Cleaning integration files..." debug normal

  #security delete-keychain ios-build.keychain
  #rm -f ~/Library/MobileDevice/Provisioning\ Profiles/*
  rm -rf ./build

  rm -rf ./report

  if [ -f $AWSCLI_CONFIG_FILENAME ]; then
  	rm $AWSCLI_CONFIG_FILENAME
  elif [ -f 'awscli_config.yml' ]; then
  	rm awscli_config.yml
  fi
}