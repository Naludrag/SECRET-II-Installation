#!/bin/bash
# # Install and configure Veyon on the server

## Adding repository to add veyon installer
sudo add-apt-repository ppa:veyon/stable -y
sudo apt-get update

## Installing veyon
sudo apt install -y veyon
## Change authentication method
sudo veyon-cli config set Authentication/Method 0
## Adding Location for computers
sudo veyon-cli networkobjects add location Secret

## Uncomment the follwoing lines to use authentication with keys
## Creating keys for client
## sudo veyon-cli authkeys create Teacher
## Change group so that only professors can see the private key and open veyon master
## sudo chgrp professor /etc/veyon/keys/private/Teacher/
## sudo veyon-cli authkeys export Teacher/public /tmp/Teacherexport
## Import publi key in the client
## schroot -c focal -u root cp /tmp/Teacherexport .

sudo pip install py-zabbix

## Create Python script to discover available clients for Veyon
sudo tee /usr/local/bin/discover_clients_veyon.py > /dev/null << EOF
"""
Script to get the clients and add it in Veyon
"""
from pyzabbix.api import ZabbixAPI
import os
import subprocess

# Variables that will be used to connect to zabbix
url = "http://localhost/zabbix/"
# ***EDIT***
# Default User used if other user please change it
username = "Admin"
password = "zabbix"
# Connection to the zabbix API
zapi = ZabbixAPI(url=url, user=username, password=password)

# Get the hosts known by Veyon
hosts = subprocess.Popen("sudo veyon-cli networkobjects list | grep \"Computer\" | awk '{print \$2 \$5}'",
                         stdout=subprocess.PIPE, shell=True)
# Get the result of the command
hosts, err = hosts.communicate()
# Parse the result
hosts = hosts.replace(b'""', b',')
hosts = hosts.replace(b'"', b'')
hosts = hosts.split(b'\n')
hostsIp = []
# Get the IP os the hosts
for h in hosts:
    hostsIp.append(h.split(b","))
# To remove \n value
hostsIp.pop()

# Will add the new hosts in Veyon if they do not exist yet
for h in zapi.hostinterface.get(output=["dns", "ip", "useip"], selectHosts=["host"], filter={"main": 1, "type": 1}):
    print("Adding " + h['hosts'][0]['host'] + " with IP " + h['ip'])
    # Bool that will permit to tell if we want to add the host or not
    adding = True
    # Go trough the hosts known by Veyon
    for h2 in hostsIp:
        # If the host to add is already in Veyon (IP and name) or
        # that the machine to add is localhost we will not add it
        if (str(h2[0], 'utf-8') == h['hosts'][0]['host'] and str(h2[1], 'utf-8') == h['ip']) or h['ip'] == "127.0.0.1":
            adding = False
        # Will remove a machine that as a new IP to add it again with new IP
        if str(h2[1], 'utf-8') != h['ip'] and str(h2[0], 'utf-8') == h['hosts'][0]['host']:
            print("Removing {} because his IP changed will be added again").format(h['hosts'][0]['host'])
            commande = "sudo veyon-cli networkobjects remove {}".format(h['hosts'][0]['host'])
            print(os.system(commande))

    # To add a machine the command line of Veyon will be used. The machines will all be added in the parent Secret
    # Please be careful that this parent exists if not the command will fail
    if adding:
        commande = "sudo veyon-cli networkobjects add computer {} {} \"\" Secret".format(h['hosts'][0]['host'], h['ip'])
        print(os.system(commande))
    else:
        print("Host already handled by veyon not adding it")

# Logout from the Zabbix api
zapi.user.logout()
EOF
