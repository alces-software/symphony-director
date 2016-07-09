#!/bin/bash -x

. /etc/symphony.cfg

COBBLER=1

############# START COBBLER ###################
if [ $COBBLER -gt 0 ]; then
  /opt/symphony/director/cobbler/bin/install_all.sh
fi
############# END COBBLER ###################

