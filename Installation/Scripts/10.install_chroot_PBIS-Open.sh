#!/bin/bash
# Install and configure PBIS-Open on the client

# To communicate with the DNS server of the school and make LDAP connections
sudo tee /etc/systemd/resolved.conf > /dev/null << 'EOF'
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.
#
# Entries in this file show the compile time defaults.
# You can change settings by editing this file.
# Defaults can be restored by simply deleting this file.
#
# See resolved.conf(5) for details

[Resolve]
DNS=10.192.22.5
#FallbackDNS=
#Domains=
#LLMNR=no
#MulticastDNS=no
#DNSSEC=no
#DNSOverTLS=no
#Cache=no-negative
#DNSStubListener=yes
#ReadEtcHosts=yes
EOF

#Install PBIS Open
wget -O - http://repo.pbis.beyondtrust.com/yum/RPM-GPG-KEY-pbis | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pbiso.list http://repo.pbis.beyondtrust.com/apt/pbiso.list
## Install pbis-open
sudo apt-get update && sudo apt-get install pbis-open -y
## Remove avahi-daemon because it has problems with PBIS
sudo apt-get remove avahi-daemon -y
sudo apt autoremove -y
sudo tee /etc/sudoers.d/ltsp_roles > /dev/null << 'EOF'
%professor   ALL=(ALL:ALL) ALL
%profs       ALL=(ALL:ALL) ALL
EOF
## Creation of scripts to add machines in the AD
tee /etc/ldap/connection.sh > /dev/null << 'EOF'
#!/usr/bin/expect -f
log_user 0
spawn /etc/ldap/run_command.sh
expect "tbaddvm@EINET.AD.EIVD.CH's password: "
send "BL291+pz&A2d\r"
log_user 1
expect "SUCCESS\r"
EOF

tee /etc/ldap/run_command.sh > /dev/null << 'EOF'
#!/bin/bash
/opt/pbis/sbin/lwsmd --start-as-daemon

sudo /opt/pbis/bin/config LoginShellTemplate /bin/bash
sudo /opt/pbis/bin/config AssumeDefaultDomain true
sudo /opt/pbis/bin/config UserDomainPrefix einet
sudo /opt/pbis/bin/config HomeDirTemplate %H/%D/%U
sudo /opt/pbis/bin/config SkeletonDirs "/etc/skelStudents"

sudo /opt/pbis/bin/domainjoin-cli join --ou TB-STUD einet.ad.eivd.ch tbaddvm
EOF

tee /etc/ldap/leave.sh > /dev/null << 'EOF'
#!/usr/bin/expect -f
log_user 0
spawn /etc/ldap/run_leave_command.sh
expect "tbaddvm@EINET.AD.EIVD.CH's password: "
send "BL291+pz&A2d\r"
log_user 1
expect "SUCCESS\r"
exec /opt/pbis/bin/lwsm shutdown
EOF


tee /etc/ldap/run_leave_command.sh > /dev/null << 'EOF'
#!/bin/bash
sudo domainjoin-cli leave --deleteAccount tbaddvm
EOF

## Set the rights correctly on the scripts so that students cannot access it and see the password
sudo chmod 750 /etc/ldap/*.sh
