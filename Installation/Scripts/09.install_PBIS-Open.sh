#!/bin/bash
# Install and configure PBIS-Open on the server

# Add apt source to install PBIS-Open
sudo wget -O - http://repo.pbis.beyondtrust.com/yum/RPM-GPG-KEY-pbis | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pbiso.list http://repo.pbis.beyondtrust.com/apt/pbiso.list
## Install PBIS-Open
sudo apt-get update && sudo apt-get install pbis-open -y
## Remove avahi-daemon because it has problems with PBIS
sudo apt-get remove avahi-daemon -y
sudo apt autoremove -y
## Will add the server to the AD. Will ask for password of the user entered
## You will have to own an account that has permisson to add machines in the AD to be able to run this command
## If the account tbaddvm is no longer available please contact the IT department
sudo /opt/pbis/bin/domainjoin-cli join --ou TB-STUD einet.ad.eivd.ch tbaddvm
## Small changes to have a better configuration
sudo /opt/pbis/bin/config LoginShellTemplate /bin/bash
sudo /opt/pbis/bin/config AssumeDefaultDomain true
sudo /opt/pbis/bin/config UserDomainPrefix einet
sudo /opt/pbis/bin/config HomeDirTemplate %H/%D/%U

## Professors from the AD can run sudo commands
sudo tee /etc/sudoers.d/ltsp_roles > /dev/null << 'EOF'
%professor   ALL=(ALL:ALL) ALL
%profs       ALL=(ALL:ALL) ALL
EOF
## Pleae restart the server to complete the installation
