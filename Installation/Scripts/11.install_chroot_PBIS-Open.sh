#!/bin/bash
# Install and configure PBIS-Open on the client

wget -O - http://repo.pbis.beyondtrust.com/yum/RPM-GPG-KEY-pbis | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pbiso.list http://repo.pbis.beyondtrust.com/apt/pbiso.list
## Install pbis-open
sudo apt-get update && sudo apt-get install pbis-open -y
sudo apt-get install ssh -y
## Remove avahi-daemon because it has problems with PBIS
sudo apt-get remove avahi-daemon -y
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
sudo /opt/pbis/bin/config RemoteDirTemplate "%H/%U"

sudo /opt/pbis/bin/domainjoin-cli join --trustEnumerationWaitSeconds 60 --ou TB-STUD einet.ad.eivd.ch tbaddvm
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
sudo chmod 740 /etc/ldap/*.sh
