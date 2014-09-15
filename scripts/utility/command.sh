#!/bin/bash

#
# Checks if command exists and exits if not
#
check_command()
{
  command -v $1 >/dev/null 2>&1 || { eval $2; exit 1; }
}
