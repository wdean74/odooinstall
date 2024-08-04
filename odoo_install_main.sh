###############################################################
# Script for installing Odoo 17.0 on Ubuntu Server 24.04
#--------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
#--------------------------------------------------------------
# Author: Dean Damon
###############################################################

USER="odoo"
HOME="/opt/$USER"
VERSION="17.0"
HOME_EXT="/$HOME/${USER}${VERSION}"
PORT="8069"
# Set the superadmin password
SUPERADMIN="stronglongpassphrase"
CONFIG="${USER}${VERSION}"

#--------------------------------------------------
# Update and upgrade
#--------------------------------------------------

echo -e "\n---- Update Server ----"
sudo apt update
sudo apt upgrade -y

#--------------------------------------------------
# Install postgresql
#--------------------------------------------------

echo -e "\n---- Install PostgreSQL Server ----"
sudo apt-get install postgresql postgresql-server-dev-all -y

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $USER"

#--------------------------------------------------
# Install dependencies
#--------------------------------------------------

echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt install python3 python3-pip -y

# These packages are for odoo 17.0 - UPDATE IF NOT USING 17.0
sudo apt install build-essential wget git python3.11-dev python3.11-venv libfreetype-dev libxml2-dev libzip-dev libsasl2-dev node-less libjpeg-dev zlib1g-dev libpq-dev libxslt1-dev libldap2-dev libtiff5-dev libopenjp2-7-dev libcap-dev -y
sudo apt install wkhtmltopdf -y

echo -e "\n---- Install python packages/requirements ----"
sudo -H pip3 install -r https://github.com/odoo/odoo/raw/${VERSION}/requirements.txt

echo -e "\n---- Installing nodeJS NPM and rtlcss for LTR support ----"
sudo apt-get install nodejs npm -y
sudo npm install -g rtlcss

#--------------------------------------------------
# Create odoo user and log path
#--------------------------------------------------

echo -e "\n---- Create odoo system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$HOME --gecos '$USER' --group $USER
#The user should also be added to the sudo'ers group.
sudo adduser $USER sudo

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$USER
sudo chown $USER:$USER /var/log/$USER

#--------------------------------------------------
# Install odoo
#--------------------------------------------------

echo -e "\n==== Installing ODOO Server ===="
sudo git clone https://www.github.com/odoo/odoo --depth 1 --branch $VERSION $HOME_EXT

echo -e "\n---- Create custom module directory ----"
sudo su $USER -c "mkdir $HOME_EXT/custom-addons"

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $USER:$USER $HOME/*

echo -e "* Create server config file"

# Modify the file below as required for your configuration
sudo cat <<EOF > /etc/${CONFIG}.conf
[options]
admin_passwd = ${SUPERADMIN}
db_host = False
db_port = False
db_user = ${USER}
db_password = False
addons_path = ${HOME_EXT}/addons,${HOME_EXT}/custom-addons
EOF

sudo chown $USER:$USER /etc/${CONFIG}.conf
sudo chmod 640 /etc/${CONFIG}.conf

#--------------------------------------------------
# Install odoo requirements
#--------------------------------------------------

sudo pip3 install wheel setuptools pip --upgrade
sudo pip3 install -r ${HOME_EXT}/requirements.txt

#--------------------------------------------------
# Create service for odoo
#--------------------------------------------------

echo -e "Creating odoo service"
sudo touch /etc/systemd/system/$CONFIG.service
# Modify the file below as required for your configuration
cat <<EOF > /etc/systemd/system/$CONFIG.service
[Unit]
Description=${CONFIG}
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo17
PermissionsStartOnly=true
User=${USER}
Group=${USER}
ExecStart=${HOME_EXT}/odoo-bin -c /etc/${CONFIG}.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
echo -e "Starting odoo"
sudo systemctl enable --now ${CONFIG}

#--------------------------------------------------
# Completion
#--------------------------------------------------

echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "User service: $USER"
echo "Configuraton file location: /etc/${CONFIG}.conf"
echo "Logfile location: /var/log/$USER"
echo "User PostgreSQL: $USER"
echo "Code location: $HOME_EXT"
echo "Password superadmin (database): $SUPERADMIN"
echo "Start Odoo service: sudo systemctl enable --now $CONFIG"
echo "Stop Odoo service: sudo systemctl disable $CONFIG"
echo "Restart Odoo service: sudo systemctl restart $CONFIG"
echo "-----------------------------------------------------------"