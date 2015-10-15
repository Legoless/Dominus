#!/bin/bash

###############################################################################
#
# Run a command; post it and its standard input, output, and error to Slack.
#
# This program expects SLACK_WEBHOOK_URL in its environment.  You can get one
# by creating a new Incoming Webhook at <https://my.slack.com/services/new>.
#
#/ Usage: slack [--attach] [--channel=<channel>] [--stdin] ...
#/   --attach            post to Slack with an attachment (defaults to fixed-width text)
#/   --channel=<channel> post to this Slack channel (defaults to the integration's default channel)
#/   --webhook           webhook to use
###############################################################################

# exit on failure
set -e

usage() {
    grep "^#/" "$0" | cut -c"4-" >&2
    exit "$1"
}

SLACK_CHANNEL="null"
SLACK_WEBHOOK_URL=""
SLACK_USERNAME=""
SLACK_MESSAGE=""

while [ "$#" -gt 0 ]
do
    case "$1" in
        --channel) SLACK_CHANNEL="\"$2\""; shift 2;;
        --channel=*) SLACK_CHANNEL="\"$(echo "$1" | cut -d"=" -f"2-")\""; shift;;
        --webhook) SLACK_WEBHOOK_URL="\"$2\""; shift 2;;
        --webhook=*) SLACK_WEBHOOK_URL="\"$(echo "$1" | cut -d"=" -f"2-")\""; shift;;
        --user) SLACK_USERNAME="\"$2\""; shift 2;;
        --user=*) SLACK_USERNAME="\"$(echo "$1" | cut -d"=" -f"2-")\""; shift;;
        --message) SLACK_MESSAGE="\"$2\""; shift 2;;
        --message=*) SLACK_MESSAGE="\"$(echo "$1" | cut -d"=" -f"2-")\""; shift;;
        -h|--help) usage 0;;
        -*) usage 1;;
        *) break;;
    esac
done

if [ -z "$SLACK_MESSAGE" ]; then
  # read stdin
  SLACK_MESSAGE=$(cat)
fi

# Clean up quotes, newlines, tabs, and control characters for a JSON string.
jsonify() {
    tr "\n\t" "\036\037" |
    sed "s/$(printf "\036")/\\\\n/g; s/$(printf "\037")/\\\\t/g; s/\"/\\\\\"/g" |
    tr -d "[:cntrl:]"
}


SLACK_CHANNEL=$(echo "$SLACK_CHANNEL" | sed -e 's/^"//'  -e 's/"$//')
SLACK_MESSAGE=$(echo "$SLACK_MESSAGE" | sed -e 's/^"//'  -e 's/"$//' | jsonify)
SLACK_USERNAME=$(echo "$SLACK_USERNAME" | sed -e 's/^"//'  -e 's/"$//')
SLACK_WEBHOOK_URL=$(echo "$SLACK_WEBHOOK_URL" | sed -e 's/^"//'  -e 's/"$//')

SLACK_PAYLOAD="{\"channel\":\"$SLACK_CHANNEL\",\"text\":\"$SLACK_MESSAGE\",\"username\":\"$SLACK_USERNAME\"}"


# Post to Slack and print the Slack API output to standard error.
#echo curl -X POST --data-urlencode "'payload="$SLACK_PAYLOAD"'" $SLACK_WEBHOOK_URL 
curl -X POST --data-urlencode 'payload='$SLACK_PAYLOAD $SLACK_WEBHOOK_URL --silent > /dev/null