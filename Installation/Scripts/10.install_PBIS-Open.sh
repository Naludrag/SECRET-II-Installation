#!/bin/bash
wget -O - http://repo.pbis.beyondtrust.com/yum/RPM-GPG-KEY-pbis | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pbiso.list http://repo.pbis.beyondtrust.com/apt/pbiso.list
## Install pbis-open
sudo apt-get update && sudo apt-get install pbis-open -y
sudo apt-get install ssh -y
## Remove avahi-daemon because it can make pbis not work
sudo apt-get remove avahi-daemon -y
## Will add the server to the ad will ask for password.
sudo /opt/pbis/bin/domainjoin-cli join --ou TB-STUD einet.ad.eivd.ch tbaddvm
## Small changes to have a better configuration
sudo /opt/pbis/bin/config LoginShellTemplate /bin/bash
sudo /opt/pbis/bin/config AssumeDefaultDomain true
sudo /opt/pbis/bin/config UserDomainPrefix einet
sudo /opt/pbis/bin/config HomeDirTemplate %H/%D/%U
## Restart the server
