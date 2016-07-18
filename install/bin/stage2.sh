#!/bin/bash -x

. /etc/symphony.cfg

SOURCE=1
SSHKEYS=1
OPENVPN=1
SYSLOG=1
PUPPET=1
COBBLER=1
METALWARE=1

YUMBASE=/opt/symphony/generic/etc/yum/centos7-base.conf

############# BEGIN SOURCE ###################
if [ $SOURCE -gt 0 ]; then
  mkdir /opt/symphony
  cd /opt/symphony
  git clone https://github.com/alces-software/symphony4.git generic
  git clone https://github.com/alces-software/symphony-director.git director
fi
############# END SOURCE ###################

############# BEGIN SSHKEYS ###################
if [ $SSHKEYS -gt 0 ]; then
  ssh-keygen -f /root/.ssh/id_symphony -N ''
cat << EOF > /root/.ssh/config
Host *
  IdentityFile ~/.ssh/id_symphony
  StrictHostKeyChecking no
EOF
fi
############# END SSHKEYS ###################

############# BEGIN OPENVPN ###################
if [ $OPENVPN -gt 0 ]; then
yum -y --config $YUMBASE --enablerepo=epel install openvpn easy-rsa facter
mkdir /etc/openvpn/easyrsa
CN=`hostname -f`
cp -pav /usr/share/easy-rsa/2.0/* /etc/openvpn/easyrsa/
sed -i /etc/openvpn/easyrsa/vars \
 -e 's|KEY_COUNTRY=.*$|KEY_COUNTRY=\"GB\"|g' \
 -e 's|KEY_PROVINCE=.*|KEY_PROVINCE=\"Oxfordshire"|g' \
 -e 's|KEY_CITY=.*|KEY_CITY=\"Bicester\"|g' \
 -e 's|KEY_ORG=.*|KEY_ORG=\"Alces Software Ltd\"|g' \
 -e 's|KEY_EMAIL=.*|KEY_EMAIL=\"ssl@alces-software.com\"|g' \
 -e 's|KEY_NAME=.*|KEY_NAME=\"server\"|g' \
 -e 's|KEY_OU=.*|KEY_OU=\"server\"|g' \
 -e "s|KEY_CN=.*|KEY_CN=\"${CN}\"|g"
cd /etc/openvpn/easyrsa/
source ./vars
./clean-all
./pkitool --initca
./pkitool --server server
./build-dh
cat << EOF > /etc/openvpn/manage.conf
port 1194
proto tcp
dev tun0
ca /etc/openvpn/easyrsa/keys/ca.crt
cert /etc/openvpn/easyrsa/keys/server.crt
key /etc/openvpn/easyrsa/keys/server.key
dh /etc/openvpn/easyrsa/keys/dh2048.pem
server 10.80.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "route 10.78.0.0 255.255.0.0"
push "route 10.110.0.0 255.255.0.0"
push "route 10.111.0.0 255.255.0.0"
duplicate-cn
keepalive 10 120
comp-lzo
persist-key
persist-tun
status openvpn-status.log
log         /var/log/openvpn.log
log-append  /var/log/openvpn.log
verb 3
client-cert-not-required
username-as-common-name
plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so openvpn-manage
EOF

FQDN=`director.$CLUSTER.compute.estate`
cat << EOF > /etc/openvpn/manage.client.conf
client
dev tun
proto tcp
remote $FQDN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
auth-user-pass
ns-cert-type server
comp-lzo
verb 3
EOF

cat << EOF > /etc/openvpn/manage.users
admin
EOF

#Only allow specific users
sed -e "/^account    required     pam_nologin.so$/iauth       required     pam_listfile.so onerr=fail item=group sense=allow file=/etc/openvpn/manage.users" /etc/pam.d/login  > /etc/pam.d/openvpn-manage

systemctl enable openvpn@manage.service
systemctl start openvpn@manage.service

#Create management vpn user
useradd admin
echo "admin:${ADMINPASSWORD}" | chpasswd
usermod admin -s /sbin/nologin

firewall-cmd --new-zone vpn --permanent
firewall-cmd --set-target ACCEPT --zone vpn --permanent
firewall-cmd --zone vpn --add-interface tun0 --permanent
firewall-cmd --add-port 1194/tcp --zone external --permanent
firewall-cmd --add-rich-rule 'rule family="ipv4" source address="10.80.0.0/24" masquerade' --zone mgt --permanent
firewall-cmd --add-rich-rule 'rule family="ipv4" source address="10.80.0.0/24" masquerade' --zone prv --permanent
firewall-cmd --add-rich-rule 'rule family="ipv4" source address="10.80.0.0/24" masquerade' --zone bld --permanent
firewall-cmd --add-rich-rule 'rule family="ipv4" source address="10.80.0.0/24" masquerade' --zone pub --permanent
firewall-cmd --reload

ln -sn /etc/openvpn/easyrsa/keys/ca.crt /etc/openvpn/.
fi
############# END OpenVPN ###################

############# BEGIN SYSLOG ###################
if [ $SYSLOG -gt 0 ]; then
  yum --config $YUMBASE --enablerepo=epel install rsyslog
  systemctl enable rsyslog
  firewall-cmd --add-port 514/udp --zone bld --permanent
  firewall-cmd --add-port 514/tcp --zone bld --permanent
  sed -i '/#### RULES ####/a & ~' /etc/rsyslog.conf
  sed -i '/#### RULES ####/a :fromhost-ip, !isequal, "127.0.0.1" ?remoteMessage' /etc/rsyslog.conf
  sed -i '/#### RULES ####/a $template remoteMessage, "/var/log/slave/%FROMHOST%/messages.log"' /etc/rsyslog.conf
  sed -i -e "s/^#\$ModLoad imudp.*$/\$ModLoad imudp/g" /etc/rsyslog.conf
  sed -i -e "s/^#\$UDPServerRun 514.*$/\$UDPServerRun 514/g" /etc/rsyslog.conf
  sed -i -e "s/^#\$ModLoad imtcp.*$/\$ModLoad imtcp/g" /etc/rsyslog.conf
  sed -i -e "s/^#\$InputTCPServerRun 514.*$/\$InputTCPServerRun 514/g" /etc/rsyslog.conf

  #log rotate
  cat << EOF > /etc/logrotate.d/rsyslog-remote
/var/log/slave/*/*.log {
    sharedscripts
    compress
    rotate 2
    postrotate
        /bin/kill -HUP \`cat /var/run/syslogd.pid 2> /dev/null\` 2> /dev/null || true
        /bin/kill -HUP \`cat /var/run/rsyslogd.pid 2> /dev/null\` 2> /dev/null || true
    endscript
}
EOF
  #fix bug with virt-sysprep cleaning /var/log/spooler
  sed -i -e "s/sharedscripts/missingok\n    sharedscripts/g" /etc/logrotate.d/syslog
  systemctl restart rsyslog
fi
############# END SYSLOG ###################

############# BEGIN PUPPET ###################
if [ $PUPPET -gt 0 ]; then
  yum -y --config $YUMBASE --enablerepo=epel --enablerepo=puppet-deps --enablerepo=puppet-base install puppet puppet-server hiera httpd httpd-devel mod_ssl ruby-devel rubygems gcc gcc-c++ libcurl-devel openssl-devel zlib-devel ruby rubygem-rack
  gem install passenger
  passenger-install-apache2-module -a
  #Configure
  cat << EOF > /etc/puppet/puppet.conf
[main]
    vardir = /var/lib/puppet
    logdir = /var/log/puppet
    rundir = /var/run/puppet
    ssldir = /var/lib/puppet/ssl
    allow_duplicate_certs = true
    pluginsync  = true
    hiera_config=/etc/puppet/hiera.yaml
    #dns_alt_names=
[agent]
    classfile = \$vardir/classes.txt
    localconfig = \$vardir/localconfig
    report      = true
    pluginsync  = true
    certname    = director
    server      = director
    listen      = false
    environment = production
[master]
    reports     = store
    certname    = director
    ca = true
    environmentpath = \$confdir/environments/
EOF
  cat << EOF > /etc/puppet/hiera.yaml
---
:backends:
  - yaml
:yaml:
  :datadir: /etc/puppet/environments/%{environment}/hieradata/
:hierarchy:
  - common
  - "%{::clientcert}"
  - "%{::alces_hostname}"
  - "%{::hostname}"
  - "%{::alces_machine}"
  - "%{::alces_role}"
  - "%{::environment}"
  - network
  - cluster
  - site
EOF
  #Create default puppet env
  mv /etc/puppet/environments/example_env /etc/puppet/environments/production
  #Invoke generation of initial certs
  systemctl start puppetmaster
  sleep 10
  puppet agent -t --waitforcert 10
  systemctl stop puppetmaster
  #Configure HTTP
  PASSENGER_MOD=`find /usr/local/share/gems/gems/passenger-* -type f -iname mod_passenger.so -printf '%T@ %p\n'| sort -n | tail -1 | cut -f2- -d" "`
  PASSENGER_ROOT=`echo $PASSENGER_MOD | sed -e 's|/buildout/apache2/mod_passenger.so||'`
  cat << EOF > /etc/httpd/conf.d/passenger.conf
LoadModule passenger_module $PASSENGER_MOD
<IfModule mod_passenger.c>
   PassengerRoot $PASSENGER_ROOT
   PassengerRuby /usr/bin/ruby
   PassengerEnabled off
</IfModule>
EOF
  cat << EOF > /etc/httpd/conf.d/puppet-master.conf
PassengerHighPerformance On
PassengerMaxPoolSize 12
PassengerMaxRequests 1000
PassengerPoolIdleTime 600

Listen 8140
<VirtualHost *:8140>
    PassengerEnabled On
    SSLEngine On

    SSLProtocol             All -SSLv2
    SSLCipherSuite          HIGH:!ADH:RC4+RSA:-MEDIUM:-LOW:-EXP
    SSLCertificateFile      /var/lib/puppet/ssl/certs/director.pem
    SSLCertificateKeyFile   /var/lib/puppet/ssl/private_keys/director.pem
    SSLCertificateChainFile /var/lib/puppet/ssl/ca/ca_crt.pem
    SSLCACertificateFile    /var/lib/puppet/ssl/ca/ca_crt.pem
    SSLCARevocationFile     /var/lib/puppet/ssl/ca/ca_crl.pem
    SSLCARevocationCheck    chain
    SSLVerifyClient         optional
    SSLVerifyDepth          1
    SSLOptions              +StdEnvVars +ExportCertData
    RequestHeader set X-SSL-Subject %{SSL_CLIENT_S_DN}e
    RequestHeader set X-Client-DN %{SSL_CLIENT_S_DN}e
    RequestHeader set X-Client-Verify %{SSL_CLIENT_VERIFY}e

    DocumentRoot /usr/share/puppet/rack/puppetmasterd/public
    <Directory /usr/share/puppet/rack/puppetmasterd/>
        Options None
        AllowOverride None
        Order Allow,Deny
        Allow from All
    </Directory>
    ErrorLog /var/log/httpd/puppet-server.example.com_ssl_error.log
    CustomLog /var/log/httpd/puppet-server.example.com_ssl_access.log combined
</VirtualHost>
EOF
  mkdir -p /usr/share/puppet/rack/puppetmasterd
  mkdir /usr/share/puppet/rack/puppetmasterd/public /usr/share/puppet/rack/puppetmasterd/tmp
  cp /usr/share/puppet/ext/rack/config.ru /usr/share/puppet/rack/puppetmasterd/
  chown puppet:puppet /usr/share/puppet/rack/puppetmasterd/config.ru

  systemctl restart httpd
  #Open firewall
  firewall-cmd --add-port 8140/tcp --zone bld --permanent
fi
############# END PUPPET ###################

############# START COBBLER ###################
if [ $COBBLER -gt 0 ]; then
  yum -y --config $YUMBASE --enablerepo=epel --enablerepo=cobbler install cobbler httpd dhcp fence-agents tftp xinetd tftp-server cobbler-web bind bind-utils bind-chroot
  #set default passwords
  PASS=`echo "${ROOTPASSWORD}" | openssl passwd -1 -stdin`
  sed -i /etc/cobbler/settings -e "s|^default_password_crypted.*|default_password_crypted: \"$PASS\"|g"
  #set master ip
  IP=`hostname -i`; sed -i /etc/cobbler/settings -e "s/^server:.*/server: $IP/g"
  IP=`hostname -i`; sed -i /etc/cobbler/settings -e "s/^next_server:.*/next_server: $IP/g"
  #Enable dhcp management
  sed -ri /etc/cobbler/settings -e "s/^#?manage_dhcp.*/manage_dhcp: 1/g"
  #Enable DNS
  sed -ri /etc/cobbler/settings -e "s/^#?manage_dns.*/manage_dns: 1/g"
  sed -ri /etc/cobbler/settings -e "s/^#?manage_forward_zones.*/manage_forward_zones: ['bld.$CLUSTER.compute.estate','prv.$CLUSTER.compute.estate','mgt.$CLUSTER.compute.estate','pub.$CLUSTER.compute.estate']/g"
  sed -ri /etc/cobbler/settings -e "s/^#?manage_reverse_zones.*/manage_reverse_zones: ['10.78']/g"
  #Enable Puppet management
  sed -ri /etc/cobbler/settings \
  -e "s/^#?puppet_auto_setup:.*/puppet_auto_setup: 1/g" \
  -e "s/^#?sign_puppet_certs_automatically:.*/sign_puppet_certs_automatically: 1/g" \
  -e "s/^#?remove_old_puppet_certs_automatically:.*/remove_old_puppet_certs_automatically: 1/g" \
  -e "s/^#?puppet_version:.*/puppet_version: 3/g" \
  -e "s/^#?puppet_server:.*/puppet_server: director/g" \
  -e "s/^#?puppetca_path:.*/puppetca_path: \/usr\/bin\/puppet/g"

  #Other
  sed -i /etc/cobbler/settings -e "s/^pxe_just_once.*$/pxe_just_once: 1/g"
  cat << EOF > /etc/cobbler/dhcp.template
#Configure dhcp template
# ******************************************************************
# Cobbler managed dhcpd.conf file
#
# generated from cobbler dhcp.conf template (\$date)
# Do NOT make changes to /etc/dhcpd.conf. Instead, make your changes
# in /etc/cobbler/dhcp.template, as /etc/dhcpd.conf will be
# overwritten.
#
# ******************************************************************

ddns-update-style interim;

allow booting;
allow bootp;

ignore client-updates;
set vendorclass = option vendor-class-identifier;

option pxe-system-type code 93 = unsigned integer 16;

subnet 10.78.0.0 netmask 255.255.0.0 {
     option routers             10.78.254.1;
     option domain-name-servers 10.78.254.1;
     option domain-search "bld.$CLUSTER.compute.estate","prv.$CLUSTER.compute.estate","mgt.$CLUSTER.compute.estate","pub.$CLUSTER.compute.estate","$CLUSTER.compute.estate";
     option subnet-mask         255.255.0.0;
     #range dynamic-bootp        10.78.0.1 10.78.0.254;
     default-lease-time         21600;
     max-lease-time             43200;
     next-server                \$next_server;
     class "pxeclients" {
          match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
          if option pxe-system-type = 00:02 {
                  filename "ia64/elilo.efi";
          } else if option pxe-system-type = 00:06 {
                  filename "grub/grub-x86.efi";
          } else if option pxe-system-type = 00:07 {
                  filename "grub/grub-x86_64.efi";
          } else {
                  filename "pxelinux.0";
          }
     }

}

#for dhcp_tag in \$dhcp_tags.keys():
    ## group could be subnet if your dhcp tags line up with your subnets
    ## or really any valid dhcpd.conf construct ... if you only use the
    ## default dhcp tag in cobbler, the group block can be deleted for a
    ## flat configuration
# group for Cobbler DHCP tag: \$dhcp_tag
group {
        #for mac in \$dhcp_tags[\$dhcp_tag].keys():
            #set iface = \$dhcp_tags[\$dhcp_tag][\$mac]
    host \$iface.name {
        hardware ethernet \$mac;
        #if \$iface.ip_address:
        fixed-address \$iface.ip_address;
        #end if
        #if \$iface.hostname:
        option host-name "\$iface.hostname";
        #end if
        #if \$iface.netmask:
        option subnet-mask \$iface.netmask;
        #end if
        #if \$iface.gateway:
        option routers \$iface.gateway;
        #end if
        #if \$iface.enable_gpxe:
        if exists user-class and option user-class = "gPXE" {
            filename "http://\$cobbler_server/cblr/svc/op/gpxe/system/\$iface.owner";
        } else if exists user-class and option user-class = "iPXE" {
            filename "http://\$cobbler_server/cblr/svc/op/gpxe/system/\$iface.owner";
        } else {
            filename "undionly.kpxe";
        }
        #else
        filename "\$iface.filename";
        #end if
        ## Cobbler defaults to \$next_server, but some users
        ## may like to use \$iface.system.server for proxied setups
        next-server \$next_server;
        ## next-server \$iface.next_server;
    }
        #end for
}
#end for
EOF
  #set WebUI password for 'admin' user
  PASS=`echo "${ADMINPASSWORD}" | md5sum - | awk '{ print $1 }'`
  echo "admin:Cobbler:${PASS}" > /etc/cobbler/users.digest
  systemctl start cobblerd.service
  systemctl enable cobblerd.service
  systemctl enable httpd
  systemctl restart httpd
  systemctl start xinetd
  systemctl enable xinetd
  systemctl enable dhcpd
  systemctl enable named
  #Get loaders
  cobbler get-loaders
  #configure DNS
  SITE_DNS=`grep -m1 nameserver /etc/resolv.conf | awk '{ print $2 }' `
  cat << EOF > /etc/cobbler/named.template
options {
          listen-on port 53 { any; };
          directory       "/var/named";
          dump-file       "/var/named/data/cache_dump.db";
          statistics-file "/var/named/data/named_stats.txt";
          memstatistics-file "/var/named/data/named_mem_stats.txt";
          allow-query     { any; };
          recursion yes;


          dnssec-enable no;
          dnssec-validation no;
          dnssec-lookaside auto;

          forward first;
          forwarders {
              $SITE_DNS;
          };

};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

#for \$zone in \$forward_zones
zone "\${zone}." {
    type master;
    file "\$zone";
};

#end for
#for \$zone, \$arpa in \$reverse_zones
zone "\${arpa}." {
    type master;
    file "\$zone";
};

#end for
EOF
  #generate zone files for the managed domains
  cat << EOF > /etc/cobbler/zone_templates/bld.$CLUSTER.compute.estate
\\\$TTL 300
@                       IN      SOA     \$cobbler_server. director.bld.$CLUSTER.compute.estate. (
                                        \$serial   ; Serial
                                        600         ; Refresh
                                        1800         ; Retry
                                        604800       ; Expire
                                        300          ; TTL
                                        )

                        IN      NS      \$cobbler_server.


director        IN A    10.78.254.1
@       IN MX   10  director
directory	IN A	10.78.254.2
repo		IN A	10.78.254.3
monitor	        IN A	10.78.254.4

\$cname_record

\$host_record
EOF

cat << EOF > /etc/cobbler/zone_templates/10.78
\\\$TTL 300
@                       IN      SOA     \$cobbler_server. director.bld.$CLUSTER.compute.estate. (
                                        \$serial   ; Serial
                                        600         ; Refresh
                                        1800         ; Retry
                                        604800       ; Expire
                                        300          ; TTL
                                        )

                        IN      NS      \$cobbler_server.

254.1   IN PTR   director.bld.$CLUSTER.compute.estate.;
254.2   IN PTR   directory.bld.$CLUSTER.compute.estate.;
254.3   IN PTR   repo.bld.$CLUSTER.compute.estate.;
254.4   IN PTR   monitor.bld.$CLUSTER.compute.estate.;

\$cname_record

\$host_record
EOF
  cat << EOF > /etc/cobbler/zone_templates/prv.$CLUSTER.compute.estate
\\\$TTL 300
@                       IN      SOA     \$cobbler_server. director.bld.$CLUSTER.compute.estate. (
                                        \$serial   ; Serial
                                        600         ; Refresh
                                        1800         ; Retry
                                        604800       ; Expire
                                        300          ; TTL
                                        )

                        IN      NS      \$cobbler_server.


director        IN A    10.110.254.1
@       IN MX   10  director
directory       IN A    10.110.254.2
repo            IN A    10.110.254.3
monitor         IN A    10.110.254.4

\$cname_record

\$host_record
EOF

cat << EOF > /etc/cobbler/zone_templates/10.110
\\\$TTL 300
@                       IN      SOA     \$cobbler_server. director.bld.$CLUSTER.compute.estate. (
                                        \$serial   ; Serial
                                        600         ; Refresh
                                        1800         ; Retry
                                        604800       ; Expire
                                        300          ; TTL
                                        )

                        IN      NS      \$cobbler_server.

254.1   IN PTR   director.prv.$CLUSTER.compute.estate.;
254.2   IN PTR   directory.prv.$CLUSTER.compute.estate.;
254.3   IN PTR   repo.prv.$CLUSTER.compute.estate.;
254.4   IN PTR   monitor.prv.$CLUSTER.compute.estate.;

\$cname_record

\$host_record
EOF
  cat << EOF > /etc/cobbler/zone_templates/mgt.$CLUSTER.compute.estate
\\\$TTL 300
@                       IN      SOA     \$cobbler_server. director.bld.$CLUSTER.compute.estate. (
                                        \$serial   ; Serial
                                        600         ; Refresh
                                        1800         ; Retry
                                        604800       ; Expire
                                        300          ; TTL
                                        )

                        IN      NS      \$cobbler_server.


director        IN A    10.111.254.1
@       IN MX   10  director
directory       IN A    10.111.254.2
repo            IN A    10.111.254.3
monitor         IN A    10.111.254.4

\$cname_record

\$host_record
EOF

cat << EOF > /etc/cobbler/zone_templates/10.111
\\\$TTL 300
@                       IN      SOA     \$cobbler_server. director.bld.$CLUSTER.compute.estate. (
                                        \$serial   ; Serial
                                        600         ; Refresh
                                        1800         ; Retry
                                        604800       ; Expire
                                        300          ; TTL
                                        )

                        IN      NS      \$cobbler_server.

254.1   IN PTR   director.mgt.$CLUSTER.compute.estate.;
254.2   IN PTR   directory.mgt.$CLUSTER.compute.estate.;
254.3   IN PTR   repo.mgt.$CLUSTER.compute.estate.;
254.4   IN PTR   monitor.mgt.$CLUSTER.compute.estate.;

\$cname_record

\$host_record
EOF
  cat << EOF > /etc/cobbler/zone_templates/pub.$CLUSTER.compute.estate
\\\$TTL 300
@                       IN      SOA     \$cobbler_server. director.bld.$CLUSTER.compute.estate. (
                                        \$serial   ; Serial
                                        600         ; Refresh
                                        1800         ; Retry
                                        604800       ; Expire
                                        300          ; TTL
                                        )

                        IN      NS      \$cobbler_server.


director        IN A    10.77.254.1
@       IN MX   10  director
directory       IN A    10.77.254.2
repo            IN A    10.77.254.3
monitor         IN A    10.77.254.4

\$cname_record

\$host_record
EOF

cat << EOF > /etc/cobbler/zone_templates/10.77
\\\$TTL 300
@                       IN      SOA     \$cobbler_server. director.bld.$CLUSTER.compute.estate. (
                                        \$serial   ; Serial
                                        600         ; Refresh
                                        1800         ; Retry
                                        604800       ; Expire
                                        300          ; TTL
                                        )

                        IN      NS      \$cobbler_server.

254.1   IN PTR   director.pub.$CLUSTER.compute.estate.;
254.2   IN PTR   directory.pub.$CLUSTER.compute.estate.;
254.3   IN PTR   repo.pub.$CLUSTER.compute.estate.;
254.4   IN PTR   monitor.pub.$CLUSTER.compute.estate.;

\$cname_record

\$host_record
EOF
  #firewall
  firewall-cmd --zone bld --add-service dhcp --permanent
  firewall-cmd --zone bld --add-service tftp --permanent
  firewall-cmd --zone bld --add-service http --permanent
  firewall-cmd --add-service dns --zone bld --permanent
  firewall-cmd --add-service smtp --zone bld --permanent
  firewall-cmd --add-service ntp --zone bld --permanent
  firewall-cmd --reload
  systemctl restart cobblerd
  sleep 5
  #sync cobbler
  cobbler sync
  #fix resolv.conf
  cat << EOF > /etc/resolv.conf
search bld.$CLUSTER.compute.estate prv.$CLUSTER.compute.estate mgt.$CLUSTER.compute.estate pub.$CLUSTER.compute.estate $CLUSTER.compute.estate
nameserver 127.0.0.1  
EOF
fi
############# END COBBLER ###################

############# BEGIN METALWARE ###################
if [ $METALWARE -gt 0 ]; then
  curl -sL http://git.io/metalware-installer | sudo alces_OS=el7 /bin/bash
  cat << EOF > /opt/metalware/etc/genders
################################################################################
##
## Alces Metalware - Genders configuration
## Copyright (c) 2015 Alces Software Ltd
##
################################################################################
# APPLIANCE
director       symphony
directory      symphony
monitor        symphony
repo           symphony

# MASTER
master1 master,masters,cluster,all

# SLAVES
slave[01-10] nodes,slave,cluster,all
EOF
fi
############# END METALWARE ###################
