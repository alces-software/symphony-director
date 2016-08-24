#!/bin/bash

if ! [ -f /var/lib/symphony-stage ]; then
 STAGE=1
else
 . /var/lib/symphony-stage
fi

APPLIANCE=symphony-`hostname -s`
BRANCH=master

if ! [ -z $STAGE ]; then
  if [ $STAGE -ne 4 ]; then
    curl https://raw.githubusercontent.com/alces-software/$APPLIANCE/$BRANCH/install/bin/stage$STAGE.sh | /bin/bash -x
  fi
fi

case $STAGE in
1)
echo "STAGE=2" > /var/lib/symphony-stage
;;
2)
echo "STAGE=3" > /var/lib/symphony-stage
;;
3)
echo "STAGE=4" > /var/lib/symphony-stage
;;
esac

if ! [ -z $STAGE ]; then
  if [ $STAGE -ne 4 ]; then
    shutdown -r now
  fi
fi
