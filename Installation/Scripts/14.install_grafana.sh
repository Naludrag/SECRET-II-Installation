#!/bin/bash
# Installation and configuration of Grafana

## Install Grafana
sudo apt-get install apt-transport-https -y
sudo apt-get install software-properties-common -y
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
## Only install stable version
echo "deb https://packages.grafana.com/enterprise/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install grafana-enterprise -y
## Start grafana server
sudo systemctl daemon-reload
## To start the server at each boot
sudo systemctl enable grafana-server.service
sudo systemctl start grafana-server
## Install zabbix plugin
sudo grafana-cli plugins install alexanderzobnin-zabbix-app
sudo service grafana-server restart
## You will then find grafana on port 3000 and login admin admin

## Install the website from the github
cd /var/www/html 
sudo wget https://github.com/Naludrag/SECRET-II-Site/archive/main.zip
sudo unzip -d /var/www/html /var/www/html/main.zip
sudo rm -rf /var/www/html/main.zip
sudo mv /var/www/html/SECRET-II-Site-main/* /var/www/html/
sudo rm -rf /var/www/html/SECRET-II-Site-main
## Install module php-zip to create zip
sudo apt-get install php-zip -y
