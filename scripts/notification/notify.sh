#!/bin/bash

# exit on failure
usage()
{
  cat << EOF
Usage: $0 -p <prefix> -m <message> -l <level> -t <type>

This script will environment variables for notification configuration.

OPTIONS:
   -h             Show this message
   -p <prefix>    Prefix to the message
   -m <message>   Message to send
   -l <level>     Message log level: warn, info, debug, trace (default: debug)
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
  trace) NUM_GLOBAL_LEVEL=4;;
  [?]) NUM_GLOBAL_LEVEL=0;;
esac

#
# Strip HTML tags for local output
#

LOCAL_MESSAGE=$(echo $MESSAGE | sed -e 's/<[^>]*>//g')

if [[ ! -z $PREFIX ]]; then
  PREFIX=$(echo $PREFIX | tr '[:lower:]' '[:upper:]')

  LOCAL_MESSAGE='['$PREFIX']: '$LOCAL_MESSAGE

  #
  # Write report log at the same time
  #

  if [ ! -d './report' ]; then
    mkdir './report'
  fi

  LOG_FILENAME="$ACTION.log"

  if [[ ! -z $TRAVIS_JOB_NUMBER ]]; then
    LOG_FILENAME=$TRAVIS_JOB_NUMBER"_$ACTION.log"
  fi

  echo $LOCAL_MESSAGE >> "./report/$LOG_FILENAME"
fi

echo $LOCAL_MESSAGE

#
# Output Trace message
#

if [ $NUM_GLOBAL_LEVEL -lt $NUM_MSG_LEVEL ]; then
  exit 0
fi

#
# Add Travis to message
#

SENDER_NAME=''

if [[ ! -z $TRAVIS_COMMIT ]]; then
  SENDER_NAME=$TRAVIS_REPO_SLUG

  #
  # Cut away organization from repo slug
  #
  SENDER_NAME=${SENDER_NAME#*/}

  #
  # Limit sender name to 14 characters
  #
  SENDER_NAME=${SENDER_NAME:0:15}
  
  MESSAGE='[Build <b>#'$TRAVIS_BUILD_NUMBER'</b>]: '$MESSAGE
fi

if [[ -z $SENDER_NAME ]]; then
  SENDER_NAME='Dominus'
fi

# 
# Read HipChat stuff from environment and post a message
#

if [[ ! -z $HIPCHAT_TOKEN ]] && [[ ! -z $HIPCHAT_ROOM_ID ]]; then
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
    #echo $HIPCHAT_SCRIPT -t $HIPCHAT_TOKEN -r "$HIPCHAT_ROOM_ID" -f $SENDER_NAME -c $COLOR -i "$MESSAGE"

    OUTPUT=$($HIPCHAT_SCRIPT -t $HIPCHAT_TOKEN -r "$HIPCHAT_ROOM_ID" -f $SENDER_NAME -c $COLOR -i "$MESSAGE")
  fi
fi