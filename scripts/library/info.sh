#!/bin/bash

#
# Usage
#

help_usage()
{
  cat << EOF

Usage: $0 <action> <command>

A command line interface for iOS workflow.

Commands:
   version                 Displays script version
   help                    Displays this message

   update                  Downloads latest scripts from GitHub repository

   setup                   Executes setup commands
   integrate <action>      Executes Continuous Integration action [build, test, deploy, quality]

EOF

  help_setup
  help_about
}

#
# Help
#

help_about()
{
  cat << EOF
Author:
   Dal Rupnik <legoless@gmail.com>

Website:
   http://www.arvystate.net

EOF
}

help_setup()
{
  cat << EOF
Setup commands:
   environment     Installs all gems and tools required for Dominus
   project         Creates and configures a new project
   travis          Creates .travis.yml file with correct parameters
   certificate     Creates a development certificate and adds it to all provisioning profiles

EOF
}

#
# Version
#

version()
{
  echo '[DOMINUS]: Dominus Script Version:' $SCRIPT_VERSION
}
