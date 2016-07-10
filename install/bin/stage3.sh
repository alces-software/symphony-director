#!/bin/bash -x

. /etc/symphony.cfg

COBBLER=1
PUPPET=1

############# START COBBLER ###################
if [ $COBBLER -gt 0 ]; then
  /opt/symphony/director/cobbler/bin/install_all.sh
fi
############# END COBBLER ###################


############# START PUPPET ###################
if [ $PUPPET -gt 0 ]; then
  /opt/symphony/director/puppet/bin/install_all.sh
  /opt/symphony/director/puppet/bin/prepare_modules.sh
  systemctl restart httpd
  puppet agent -t --environment=symphony
fi
############# END PUPPET #####################
