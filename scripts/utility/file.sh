#!/bin/bash

#
# Returns first file matching path
#
find_file()
{
  FILE_PATH=''

  CURRENT_PATH='.'

  if [[ ! -z $2 ]]; then
    CURRENT_PATH=$2
  fi

  for f in $(find $CURRENT_PATH -iname $1);
  do
    if [[ -f $f ]]; then
      FILE_PATH=$f
      break
    fi
  done

  echo $FILE_PATH
}

find_dir()
{
  DIRECTORY_PATH=''

  CURRENT_PATH='.'

  if [[ ! -z $2 ]]; then
    CURRENT_PATH=$2
  fi

  for f in $(find $CURRENT_PATH -iname $1);
  do
    if [[ -d $f ]]; then
      DIRECTORY_PATH=$f
      break
    fi
  done

  echo $DIRECTORY_PATH
}

find_app()
{
  local DIRECTORY_PATH=''

  local CURRENT_PATH='.'

  if [[ ! -z $1 ]]; then
    CURRENT_PATH=$1
  fi

  for f in $(find $CURRENT_PATH -iname '*.app');
  do
    if [[ -d $f ]] && [[ $f != *.xcarchive* ]]; then
      DIRECTORY_PATH=$f
      break
    fi
  done

  echo $DIRECTORY_PATH
}

package()
{
  PACKAGE_PATH=$(dirname $1)
  BASE_PATH=$(basename $1)

  pushd $PACKAGE_PATH > /dev/null
  zip -r -q -9 $BASE_PATH.zip $BASE_PATH
  popd > /dev/null
}