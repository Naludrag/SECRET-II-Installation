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
service grafana-server restart
# You will then find grafana on port 3000 and login admin admin
