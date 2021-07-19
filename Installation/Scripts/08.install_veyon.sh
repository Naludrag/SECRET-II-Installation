#!/bin/bash
sudo apt install python3-pip
pip install pyzabbix
## Adding repository to add veyon installer
sudo add-apt-repository ppa:veyon/stable
sudo apt-get update

## Installing veyon
sudo apt install -y veyon
## Creating keys for client
## sudo veyon-cli authkeys create Teacher
## Change authentication method
sudo veyon-cli config set Authentication/Method 0
## Adding Location
sudo veyon-cli networkobjects add location Secret
## Change group so that only professors can see the private key and open veyon master
## sudo chgrp professor /etc/veyon/keys/private/Teacher/
## sudo veyon-cli authkeys export Teacher/public /tmp/Teacherexport

## schroot -c focal -u root cp /tmp/Teacherexport .
