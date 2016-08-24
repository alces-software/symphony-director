#!/bin/bash

if ! [ -f /var/run/symphony-stage ]; then
 STAGE=1
else
 . /var/run/symphony-stage
fi

APPLIANCE=symphony-director
BRANCH=master

if ! [ -z $STAGE ]; then
  curl https://raw.githubusercontent.com/alces-software/$APPLIANCE/$BRANCH/install/bin/stage$STAGE.sh | /bin/bash -x
fi

case $STAGE in
1)
echo "STAGE=2" > /var/run/symphony-stage
;;
2)
echo "STAGE=3" > /var/run/symphony-stage
;;
*)
echo "" > /var/run/symphony-stage
;;
esac

if ! [ -z $STAGE ]; then
  shutdown -r now
fi
