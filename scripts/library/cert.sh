#!/bin/bash

# exit on failure
set -e

#
# Public functions (only ones with messages in)
#

certificate_install()
{
  if [ "$ACTION" != "test" ]; then

    LOGINED_USER=$(whoami)

    message "cert" "Creating keychain for $LOGINED_USER"

    keychain_create $LOGINED_USER

    APPLE_CERT_PATH=$(find_file *.cer)
    DEVELOPER_CERT_PATH=$(find_file *.p12)

    message "cert" "Importing Apple certificate at: $APPLE_CERT_PATH" debug normal

    keychain_certificate_import $APPLE_CERT_PATH

    message "cert" "Apple certificate imported." trace normal

    message "cert" "Importing Developer certificate at: $DEVELOPER_CERT_PATH" debug normal

    keychain_certificate_import $DEVELOPER_CERT_PATH $DEVELOPER_IDENTITY_PASSWORD

    message "cert" "Developer certificate imported." trace normal
  fi
}

#
# Private functions
#

keychain_create()
{
  security create-keychain -p $1 ios-build.keychain
  security default-keychain -s ios-build.keychain
  security unlock-keychain -p $1 ios-build.keychain
  security -v set-keychain-settings -lut 7200 ios-build.keychain
}

keychain_certificate_import()
{
  IMPORT_COMMAND="security import "

  if [[ ! -z $1 ]]; then
    IMPORT_COMMAND=$IMPORT_COMMAND" $1 -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign"
  fi

  if [[ ! -z $2 ]]; then
    IMPORT_COMMAND=$IMPORT_COMMAND" -P $2"
  fi

  if [[ ! -z $1 ]]; then
    eval $IMPORT_COMMAND
  fi
}


find_signing_identity()
{
  #IDENTITIES=$(security find-identity -v ~/Library/Keychains/ios-build.keychain | grep "iPhone" | head -n1)
  IDENTITY=`security find-identity -v | grep "iPhone" | head -n1`
  IDENTITY=${IDENTITY##*iPhone}
  IDENTITY=${IDENTITY%%\"*}
  IDENTITY="\"iPhone$IDENTITY\""

  return "$IDENTITY"
}