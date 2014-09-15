#!/bin/bash

# exit on failure
usage() {
  cat << EOF
Usage: $0 -m <message> -l <level> -t <type>

This script will environment variables for notification configuration.

OPTIONS:
   -h             Show this message
   -p <prefix>      Prefix to the message
   -m <message>   Message to send
   -l <level>     Message log level: warn, info, debug (default: debug)
   -t <type>      Message type, values: error, success, warning, normal, announce (default: normal)
EOF
}

MESSAGE=""
LEVEL=""
MESSAGE_TYPE=""
PREFIX=""

while getopts “h:p:m:l:t:” OPTION; do
  case $OPTION in
    h) usage; exit 0;;
    m) MESSAGE=$OPTARG;;
    l) LEVEL=$OPTARG;;
    p) PREFIX=$OPTARG;;
    t) MESSAGE_TYPE=$OPTARG;;
    [?]) usage; exit;;
  esac
done

#
# No message, do nothing
#

if [[ -z $MESSAGE ]]; then
  exit 1
fi

#echo $MESSAGE

#
# Set defaults
#

if [[ -z $LEVEL ]]; then
  LEVEL='debug'
fi

#echo $MESSAGE_TYPE

if [[ -z $MESSAGE_TYPE ]]; then
  MESSAGE_TYPE='normal'
fi

#
# Check message level, convert log levels to numbers
#

NUM_MSG_LEVEL=1

case $LEVEL in
  warn) NUM_MSG_LEVEL=1;;
  info) NUM_MSG_LEVEL=2;;
  debug) NUM_MSG_LEVEL=3;;
  trace) NUM_MSG_LEVEL=4;;
  [?]) NUM_MSG_LEVEL=1;;
esac

NUM_GLOBAL_LEVEL=0

case $LOG_LEVEL in
  warn) NUM_GLOBAL_LEVEL=1;;
  info) NUM_GLOBAL_LEVEL=2;;
  debug) NUM_GLOBAL_LEVEL=3;;
  [?]) NUM_GLOBAL_LEVEL=0;;
esac

#echo $LOG_LEVEL=$NUM_GLOBAL_LEVEL $LEVEL=$NUM_MSG_LEVEL

#echo $HIPCHAT_TOKEN '.' $HIPCHAT_ROOM_ID

if [ $NUM_GLOBAL_LEVEL -lt $NUM_MSG_LEVEL ]; then
  exit 0
fi

#
# Read HipChat stuff from environment and post a message
#

if [[ ! -z $HIPCHAT_TOKEN ]] && [[ ! -z $HIPCHAT_ROOM_ID ]]; then

  #
  # Add Travis to message
  #

  if [[ ! -z $TRAVIS_COMMIT ]]; then
    MESSAGE='[<b>'$TRAVIS_REPO_SLUG'</b>#<i>'$TRAVIS_BUILD_NUMBER'</i>]: '$MESSAGE
  fi

  #
  # HipChat color mapping
  #

  COLOR=""

  if [ "$MESSAGE_TYPE" == "error" ]; then
    COLOR='red'
  elif [ "$MESSAGE_TYPE" == "success" ]; then
    COLOR='green'
  elif [ "$MESSAGE_TYPE" == "warning" ]; then
    COLOR='yellow'
  elif [ "$MESSAGE_TYPE" == "announce" ]; then
    COLOR='purple'
  else
    COLOR='gray'
  fi

  #
  # Search for HipChat script
  #

  HIPCHAT_SCRIPT=`find . -name hipchat.sh | head -n1`

  if [[ -f $HIPCHAT_SCRIPT ]]; then
    OUTPUT=$($HIPCHAT_SCRIPT -t $HIPCHAT_TOKEN -r "$HIPCHAT_ROOM_ID" -f Dominus -c $COLOR -i "$MESSAGE")
  fi

fi