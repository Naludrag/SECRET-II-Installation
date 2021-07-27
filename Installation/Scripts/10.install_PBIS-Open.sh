#!/bin/bash
# Install and configure PBIS-Open on the server

# Add apt source to install PBIS-Open
sudo wget -O - http://repo.pbis.beyondtrust.com/yum/RPM-GPG-KEY-pbis | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pbiso.list http://repo.pbis.beyondtrust.com/apt/pbiso.list
## Install pbis-open
sudo apt-get update && sudo apt-get install pbis-open -y
sudo apt-get install ssh -y
## Remove avahi-daemon because it has problems with PBIS
sudo apt-get remove avahi-daemon -y
sudo apt autoremove
## Will add the server to the AD will ask for password of the user entered
## You will have to possess an account that has permisson to add machines to be able to run this command
## If the account tbaddvm is no longer available please contact the IT department
sudo /opt/pbis/bin/domainjoin-cli join --ou TB-STUD einet.ad.eivd.ch tbaddvm
## Small changes to have a better configuration
sudo /opt/pbis/bin/config LoginShellTemplate /bin/bash
sudo /opt/pbis/bin/config AssumeDefaultDomain true
sudo /opt/pbis/bin/config UserDomainPrefix einet
sudo /opt/pbis/bin/config HomeDirTemplate %H/%D/%U
## Pleae restart the server to complete the installation
