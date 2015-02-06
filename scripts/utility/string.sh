#!/bin/bash

#
# Trims string of whitespace and newline
#
trim()
{
    local TRIMMED=$(echo $1 | sed -e 's/^[[:space:]]*//')

    echo $TRIMMED
}
