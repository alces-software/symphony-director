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
ZONE=build
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
ZONE=mgt
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
10.78.254.1  director.bld.$CLUSTER.compute.estate director.build
10.110.254.1 director.prv.$CLUSTER.compute.estate director.prv
10.111.254.1 director.mgt.$CLUSTER.compute.estate director.mgt
10.77.254.1  director.pub.$CLUSTER.compute.estate symphony.local director.pub
EOF


#FIREWALL
cat << EOF > /etc/sysconfig/iptables
*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A POSTROUTING -o eth4 -j MASQUERADE
-A POSTROUTING -o eth0 -j MASQUERADE
COMMIT
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
#BUILD NETWORK FORWARDING TO EXTERNAL NETWORK
-A FORWARD -i eth4 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i eth0 -o eth4 -j ACCEPT
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
#APPLIANCERULES#
#SSH
-A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF

#YUM
yum -y --config https://raw.githubusercontent.com/alces-software/symphony4/master/generic/etc/yum/centos7-base.conf update
yum -y --config https://raw.githubusercontent.com/alces-software/symphony4/master/generic/etc/yum/centos7-base.conf install vim emacs yum-utils git

#DISABLE CLOUD-INIT (WE ONLY NEED IT ONCE)
systemctl disable cloud-init
systemctl disable cloud-final
systemctl disable cloud-config
systemctl disable cloud-init-local

echo "root:${ROOTPASSWORD}" | chpasswd

