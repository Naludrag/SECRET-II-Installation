#!/bin/bash
# Installation of tests script for user

sudo tee /usr/local/bin/rights-test.sh > /dev/null << 'EOF'
#!/bin/bash
sudo chgrp www-data $1
sudo chmod 770 $1
sudo setfacl -R -m g:profs:rwx $1
EOF

sudo chmod +x /usr/local/bin/rights-test.sh

sudo tee /etc/profile.d/create-test.sh > /dev/null << 'EOF'
#!/bin/bash
if [[ $EUID -ne 0 ]]; then # Execute only when a user other than root logs in
  if [[ ! -d ~/tests ]]
  then
      mkdir ~/tests
      /usr/bin/sudo /usr/local/bin/rights-test.sh "$HOME/tests"
  fi
fi
EOF

sudo chmod +x /etc/profile.d/create-test.sh


sudo tee /etc/sudoers > /dev/null << 'EOF'
# This file MUST be edited with the 'visudo' command as root.
#
# Please consider adding local content in /etc/sudoers.d/ instead of
# directly modifying this file.
#
# See the man page for details on how to write a sudoers file.
#
Defaults        env_reset
Defaults        mail_badpass
Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"

# Host alias specification

# User alias specification

# Cmnd alias specification

# User privilege specification
root    ALL=(ALL:ALL) ALL
ALL ALL=(root) NOPASSWD:/usr/local/bin/rights-test.sh
# Members of the admin group may gain root privileges
%admin ALL=(ALL) ALL

# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL

# See sudoers(5) for more information on "#include" directives:

#includedir /etc/sudoers.d
EOF

