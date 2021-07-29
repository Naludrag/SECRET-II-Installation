#!/bin/bash
# Install and configure Veyon on the client

## Adding repository to add veyon installer
sudo add-apt-repository ppa:veyon/stable -y
sudo apt-get update

## Installing veyon
sudo apt install veyon -y
## Change authentication method
sudo veyon-cli config set Authentication/Method 0

## Uncomment the following lines to use authentication with keys
## sudo veyon-cli config set Authentication/Method 1
## Import the key
## sudo veyon-cli authkeys import Teacher/public ./Teacherexport
## sudo rm -rf ./Teacherexport

# Set access to have only profs accessing the clients
sudo veyon-cli config set AccessControl/DomainGroupsEnabled true
sudo veyon-cli config set AccessControl/AccessRestrictedToUserGroups true
sudo veyon-cli config set AccessControl/AccessControlRulesProcessingEnabled false
sudo veyon-cli config set AccessControl/AuthorizedUserGroups profs

## To start automatically veyon at each login
sudo tee /etc/xdg/autostart/veyon-start.desktop > /dev/null << 'EOF'
[Desktop Entry]
Type=Application
Name=Veyon Sever Start
Exec=sh -c "veyon-server"
X-GNOME-Autostart-enabled=true
Comment=To be able to see students screens
EOF

