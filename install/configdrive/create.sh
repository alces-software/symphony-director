#!/bin/bash

if ! [ `which genisoimage` ]; then 
  echo "You need genisoimage installed" >&2
  exit 1
fi

BASEPATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/"
cd $BASEPATH && genisoimage -o symphony-config.iso -V cidata -r -J meta-data user-data
