#!/bin/bash

#
# Returns first file matching path
#
find_file()
{
  FILE_PATH=''

  for f in $(find . -iname $1);
  do
    if [[ -f $f ]]; then
     FILE_PATH=$f
     break
    fi
  done

  echo $FILE_PATH
}

