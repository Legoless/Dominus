#!/bin/bash

clean()
{
  security delete-keychain ios-build.keychain
  rm -f ~/Library/MobileDevice/Provisioning\ Profiles/*
  rm -rf ./build
}