#!/bin/bash

. /etc/symphony.cfg

#BUILD NETWORK (PRIMARY)
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
IPV6INIT=no
BOOTPROTO=none
DEVICE=eth0
ONBOOT=yes
IPADDR=10.78.254.1
NETMASK=255.255.0.0
NETWORK=10.78.0.0
ZONE=bld
NM_CONTROLLED=no
DNS=10.78.254.1
NOZEROCONF=yes
EOF

#PRIVATE NETWORK
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
IPV6INIT=no
BOOTPROTO=none
DEVICE=eth1
IPADDR=10.110.254.1
NETMASK=255.255.0.0
ONBOOT=yes
PEERDNS=no
ZONE=prv
NM_CONTROLLED=no
NOZEROCONF=yes
EOF

#MANAGEMENT
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth2
IPV6INIT=no
BOOTPROTO=none
DEVICE=eth2
IPADDR=10.111.254.1
NETMASK=255.255.0.0
ONBOOT=yes
PEERDNS=no
ZONE=mgt
NM_CONTROLLED=no
NOZEROCONF=yes
EOF

#PUBLIC
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth3
IPV6INIT=no
BOOTPROTO=none
DEVICE=eth3
IPADDR=10.77.254.1
NETMASK=255.255.0.0
ONBOOT=yes
PEERDNS=no
ZONE=pub
NM_CONTROLLED=no
NOZEROCONF=yes
EOF

#EXT
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth4
IPV6INIT=no
BOOTPROTO=dhcp
DEVICE=eth4
ONBOOT=yes
PEERDNS=no
ZONE=external
NM_CONTROLLED=no
NOZEROCONF=yes
EOF

#HOSTFILE
cat << EOF > /etc/hosts
# The following lines are desirable for IPv4 capable hosts
127.0.0.1 localhost.localdomain localhost
127.0.0.1 localhost4.localdomain4 localhost4

# The following lines are desirable for IPv6 capable hosts
::1 localhost.localdomain localhost
::1 localhost6.localdomain6 localhost6

#Symphony
10.78.254.1  director.$CLUSTER.compute.estate director.bld.$CLUSTER.compute.estate director.build director
10.110.254.1 director.prv.$CLUSTER.compute.estate director.prv
10.111.254.1 director.mgt.$CLUSTER.compute.estate director.mgt
10.77.254.1  director.pub.$CLUSTER.compute.estate symphony.local director.pub

10.78.254.2  directory.$CLUSTER.compute.estate directory
10.78.254.3  repo.$CLUSTER.compute.estate repo
10.78.254.4  monitor.$CLUSTER.compute.estate monitor
EOF

#FIREWALL
systemctl disable iptables
systemctl enable firewalld
systemctl stop iptables
systemctl restart firewalld
firewall-cmd --zone=external --add-masquerade --permanent
firewall-cmd --new-zone bld --permanent
firewall-cmd --new-zone prv --permanent
firewall-cmd --new-zone mgt --permanent
firewall-cmd --new-zone pub --permanent

firewall-cmd --add-service ssh --zone bld --permanent
firewall-cmd --reload

#YUM
yum -y --config https://raw.githubusercontent.com/alces-software/symphony4/master/etc/yum/centos7-base.conf update
yum -y --config https://raw.githubusercontent.com/alces-software/symphony4/master/etc/yum/centos7-base.conf install vim emacs yum-utils git

#DISABLE CLOUD-INIT (WE ONLY NEED IT ONCE)
systemctl disable cloud-init
systemctl disable cloud-final
systemctl disable cloud-config
systemctl disable cloud-init-local

#Cleanup /var/lib/cloud for root password entries
rm -rf /var/lib/cloud

echo "root:${ROOTPASSWORD}" | chpasswd

#Allow root login with keys
sed -i -e "s/^PermitRootLogin.*$/PermitRootLogin without-password/g" /etc/ssh/sshd_config
