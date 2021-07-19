from pyzabbix.api import ZabbixAPI
import os
import subprocess

# Variables that will be used to connect to zabbix
url="http://localhost/zabbix/"
# Default User used if other user please change it
username="Admin"
password="zabbix"
# Connection to the zabbix API
zapi = ZabbixAPI(url=url, user=username, password=password)
# Get the hosts known by the zabbix API
hosts = zapi.host.get(monitored_hosts=1, output='extend')

# Get the hosts known by veyon
hosts=subprocess.Popen("sudo veyon-cli networkobjects list | grep \"Computer\" | awk '{print $2 $5}'", stdout=subprocess.PIPE, shell=True)
hosts,err=hosts.communicate()
# Parse the result
hosts=hosts.replace(b'""', b',')
hosts=hosts.replace(b'"', b'')
hosts=hosts.split(b'\n')
hostsIp=[]
for h in hosts:
        hostsIp.append(h.split(b","))
# To remove \n value
hostsIp.pop()


# Will add the new hosts in veyon if they do not exist yet
for h in zapi.hostinterface.get(output=["dns", "ip", "useip"], selectHosts=["host"], filter={"main": 1, "type": 1}):
   print("Adding " + h['hosts'][0]['host'] + " with IP " + h['ip'])
   # Bool that will permit to tell if we want to add the host or not
   adding=True
   # Go trough the hosts known by veyon
   for h2 in hostsIp:
      # If the host to add is already in veyon or that the machine to add is localhost we will not add it
      if str(h2[0], 'utf-8') == h['hosts'][0]['host'] or h2[1] == h['ip'] or h['ip'] == "127.0.0.1":
        adding=False
   # To add a machine the command line of veyon will be used the machines will all be added in the parent Secret
   # Please be careful that this parent exists if not the command will fail
   if adding:
      commande = "sudo veyon-cli networkobjects add computer {} {} \"\" Secret".format(h['hosts'][0]['host'],h['ip'])
      print(commande)
      print(os.system(commande))
   else:
      print("Host already handled by veyon not adding it")

zapi.user.logout()