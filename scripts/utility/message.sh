#!/bin/bash

#
# Calls notify script with parameters
#
message()
{
  #
  # Find notify script
  #
  NOTIFY_SCRIPT=`find . -name notify.sh | head -n1`

  IFS=$'\n'

  if [[ -f $NOTIFY_SCRIPT ]]; then
    $NOTIFY_SCRIPT -p $1 -m $2 -l $3 -t $4
  fi
}
