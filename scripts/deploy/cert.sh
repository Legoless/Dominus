#!/bin/bash

# exit on failure
set -e

message()
{
  #
  # Find notify script
  #
  NOTIFY_SCRIPT=`find . -name notify.sh | head -n1`

  IFS=$'\n'

  if [[ -f $NOTIFY_SCRIPT ]]; then
    $NOTIFY_SCRIPT -m $1 -l $2 -t $3
  fi
}



#
# Search for certificates and install
#

LOGINED_USER=$(whoami)

echo '[CERT]: Creating keychain for' $LOGINED_USER

security create-keychain -p $LOGINED_USER ios-build.keychain
security default-keychain -s ios-build.keychain
security unlock-keychain -p $LOGINED_USER ios-build.keychain
security -v set-keychain-settings -lut 7200 ios-build.keychain

#
# Search for Apple cert
#

APPLE_CERT_PATH=''

for f in $(find . -iname apple.cer);
do
  if [[ -f $f ]]; then
    APPLE_CERT_PATH=$f
    break
  fi
done

#
# Search for developer certificate
#

DEVELOPER_CERT_PATH=''

for f in $(find . -iname *.p12);
do
  if [[ -f $f ]]; then
    DEVELOPER_CERT_PATH=$f
    break
  fi
done

#
# Import certificates
#

if [[ ! -z $APPLE_CERT_PATH ]] && [[ -f $APPLE_CERT_PATH ]]; then
  message "Importing Apple certificate..." debug normal

  echo '[CERT]: Importing Apple certificate at:' $APPLE_CERT_PATH

  security import $APPLE_CERT_PATH -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign
else
  message "Apple certificate not found. Aborting..." warn error

  echo '[CERT]: Apple certificate not found. Aborting...'
  exit 1
fi


#security import ./scripts/travis/dist.cer -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign

if [[ ! -z $DEVELOPER_CERT_PATH ]] && [[ -f $DEVELOPER_CERT_PATH ]]; then
  message "Importing Developer certificate..." debug normal

  echo '[CERT]: Importing Developer certificate at:' $DEVELOPER_CERT_PATH

  security import $DEVELOPER_CERT_PATH -k ~/Library/Keychains/ios-build.keychain -P $DEVELOPER_IDENTITY_PASSWORD -T /usr/bin/codesign
else
  message "Developer certificate not found. Aborting" warn error

  echo '[CERT]: Developer certificate not found. Aborting...'
  exit 1
fi