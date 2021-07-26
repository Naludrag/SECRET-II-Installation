#!/bin/bash
# Chrooted environment configuration
# This script must be called from inside the chroot

# Fill apt sources list
cat > /etc/apt/sources.list << 'EOF'
deb http://us.archive.ubuntu.com/ubuntu/ focal main restricted
deb http://us.archive.ubuntu.com/ubuntu/ focal-updates main restricted
deb http://us.archive.ubuntu.com/ubuntu/ focal universe
deb http://us.archive.ubuntu.com/ubuntu/ focal-updates universe
deb http://us.archive.ubuntu.com/ubuntu/ focal multiverse
deb http://us.archive.ubuntu.com/ubuntu/ focal-updates multiverse
deb http://us.archive.ubuntu.com/ubuntu/ focal-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu focal-security main restricted
deb http://security.ubuntu.com/ubuntu focal-security universe
deb http://security.ubuntu.com/ubuntu focal-security multiverse
EOF

# Prepare new repositories
apt update && apt upgrade -y
apt install software-properties-common -y
add-apt-repository ppa:ltsp -y

# Install Ubuntu desktop and others packages (skip GRUB installation)
apt update
apt install --install-recommends ltsp -y
apt install ubuntu-desktop nano linux-generic openssh-server iptables-persistent expect -y

# Set date
rm /etc/localtime
ln -s /usr/share/zoneinfo/Europe/Zurich /etc/localtime

# Generate locales
locale-gen en_US.UTF-8

# Install mitmproxy certificate :
update-ca-certificates

# Prepare gnome environment
cat > /etc/dconf/profile/user << 'EOF'
user-db:user
system-db:local
EOF
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/local << 'EOF'
[system/proxy]
mode='manual'
ignore-hosts=['localhost','127.0.0.1']

[system/proxy/http]
host='192.168.67.1'
port=8080
enabled=true

[system/proxy/https]
host='192.168.67.1'
port=8080
enabled=true
EOF
dconf update

# Add mitmproxy certificate in Firefox
cat > /usr/lib/firefox/distribution/policies.json << 'EOF'
{
    "policies": {
        "Certificates": {
            "Install": [
                "Mitmproxy",
                "/usr/local/share/ca-certificates/mitmproxy-ca-cert.crt"
            ]
        }
    }
}
EOF

# Grant professor sudo permission
cat > /etc/sudoers.d/ltsp_roles << 'EOF'
%professor	  ALL=(ALL:ALL) ALL
%EINET\\profs ALL=(ALL:ALL) ALL
EOF

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

# Creation of the service that will start syslog in Ubuntu 20.04
sudo tee /usr/local/bin/start-syslog.sh > /dev/null << 'EOF'
#!/bin/bash
sudo systemctl unmask rsyslog
sudo service rsyslog start
setfacl -m u:zabbix:r /var/log/syslog
EOF

# To make the script executable
sudo chmod +x /usr/local/bin/start-syslog.sh

# Create the service
sudo tee /etc/systemd/system/startsyslog.service > /dev/null << 'EOF'
[Unit]
Description=Start syslog

[Service]
Type=oneshot
ExecStart=/usr/bin/start-syslog.sh

[Install]
WantedBy=multi-user.target
EOF

# Enable it so that it is started when a client boots
systemctl enable startsyslog.service
