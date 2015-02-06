#!/bin/bash

# exit on failure
set -e

#
# Public functions (only ones with messages in)
#

cert()
{
  if [[ $BUILD_SDK == *simulator* ]]; then
    return 0
  fi

  LOGINED_USER=$(whoami)

  set +e

  CURRENT_KEYCHAIN=$(find_keychain)

  if [ -z "$CURRENT_KEYCHAIN" ]; then
    message "cert" "Creating keychain for $LOGINED_USER..." debug normal

    #CURRENT_KEYCHAIN=$(keychain_create $LOGINED_USER)
  fi

  if [[ ! -z $TRAVIS_BUILD_NUMBER ]]; then
    security -v set-keychain-settings -lut 7200 $CURRENT_KEYCHAIN
  fi  

  #APPLE_CERT_PATH=$(find_file *.cer)
  DEVELOPER_CERT_PATH=$(find_file *.p12)

  #message "cert" "Importing Apple certificate at: $APPLE_CERT_PATH" debug normal

  #CERTIFICATE=$(keychain_certificate_import $APPLE_CERT_PATH)

  #message "cert" "Apple certificate imported." trace normal

  message "cert" "Importing Developer certificate at: $DEVELOPER_CERT_PATH" debug normal

  DEVELOPER_CERTIFICATE_IMPORT=$(keychain_certificate_import $DEVELOPER_CERT_PATH $DEVELOPER_IDENTITY_PASSWORD)

  message "cert" "Developer certificate imported." trace normal

  set -e
}

#
# Private functions
#

keychain_create()
{
  security create-keychain -p $1 ios-build.keychain

  local KEYCHAIN=$(find_keychain)

  security default-keychain -s $KEYCHAIN
  security unlock-keychain -p $1 $KEYCHAIN
  
  echo $KEYCHAIN
}

keychain_certificate_import()
{
  IMPORT_COMMAND="security import "

  if [[ ! -z $1 ]]; then
    #IMPORT_COMMAND=$IMPORT_COMMAND" $1 -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign"
    IMPORT_COMMAND=$IMPORT_COMMAND" $1 -k $CURRENT_KEYCHAIN -T /usr/bin/codesign"
  fi

  if [[ ! -z $2 ]]; then
    IMPORT_COMMAND=$IMPORT_COMMAND" -P $2"
  fi

  if [[ ! -z $1 ]]; then
    local IMPORT_EXECUTE=`eval $IMPORT_COMMAND`
  fi
}

find_signing_identity()
{
  local DEVELOPER_CERT_PATH=$(find_file *.p12)

  if [[ ! -z $DEVELOPER_CERT_PATH ]]; then
    DEVELOPER_CERTIFICATE_IDENTITY=$(get_friendly_name $DEVELOPER_CERT_PATH $DEVELOPER_IDENTITY_PASSWORD)
  else
    DEVELOPER_CERTIFICATE_IDENTITY=$(find_installed_signing_identity)
  fi

  echo $DEVELOPER_CERTIFICATE_IDENTITY
}

find_keychain()
{
  local KEYCHAIN=`security default-keychain -d user | head -n1`
  KEYCHAIN=$(trim $KEYCHAIN)

  echo "$KEYCHAIN"
}

get_friendly_name()
{
  local FRIENDLY_NAME=$(openssl pkcs12 -in $1 -info -password pass:$2 -nokeys)
  FRIENDLY_NAME=${FRIENDLY_NAME##*friendlyName:}
  FRIENDLY_NAME=${FRIENDLY_NAME%%localKeyID*}
  FRIENDLY_NAME=$(trim $FRIENDLY_NAME)

  echo $FRIENDLY_NAME
}

find_installed_signing_identity()
{
  #IDENTITIES=$(security find-identity -v ~/Library/Keychains/ios-build.keychain | grep "iPhone" | head -n1)
  local IDENTITY=`security find-identity -v | grep "iPhone" | head -n1`
  IDENTITY=${IDENTITY##*iPhone}
  IDENTITY=${IDENTITY%%\"*}
  IDENTITY="\"iPhone$IDENTITY\""
  IDENTITY=$(trim $IDENTITY)

  echo "$IDENTITY"
}
