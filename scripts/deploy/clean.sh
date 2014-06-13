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

#security delete-keychain ios-build.keychain
rm -f ~/Library/MobileDevice/Provisioning\ Profiles/*
rm -rf ./build