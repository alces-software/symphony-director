#!/bin/bash -x

. /etc/symphony.cfg

COBBLER=1
PUPPET=1
DASH=1

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
  sed -i -e "s/^symphonydirector::clientname:.*$/symphonydirector::clientname: '${CLUSTER}'/g" /opt/symphony/director/puppet/environments/symphony/hieradata/site.yaml
  puppet agent -t --environment=symphony
fi
############# END PUPPET #####################

############# START DASH ###################
if [ $DASH -gt 0 ]; then
  curl -L https://raw.githubusercontent.com/alces-software/symphony-management-dashboard/master/scripts/install | /bin/bash
  sed -i -e "s/your cluster/$CLUSTER/g" /opt/symphony-management-dashboard/htdocs/index.html
fi
############# END DASH ###################

############# START CLEANUP ##############
sed -i '/.*ephemeral0.*/d' /etc/fstab &&
    systemctl reset-failed
history -c
############# END CLEANUP ################
