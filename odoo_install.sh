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

# User is used for naming path, service, and database
# I often have multiple installs on one machine and like the convention odoo{version}{com or ent}{counter}

USER="odoo17com1"
HOME="/opt/$USER"
VERSION="17.0"
# Enterprise?
ENTERPRISE="False"
# Intall dependecies in venv?
VENV="True"
# Set the superadmin password
SUPERADMIN="stronglongpassphrase"
CONFIG="${USER}"
CONFPATH="/etc/$USER.conf"
EXECSTART="$HOME/odoo-bin -c $CONFPATH"
ADDONSPATH="${HOME}/addons,${HOME}/custom-addons"

#--------------------------------------------------
# Update and upgrade
#--------------------------------------------------

echo -e "\n---- Update Server ----"
sudo apt update
sudo apt upgrade -y

#--------------------------------------------------
# Install postgresql
#--------------------------------------------------

echo "\n---- Install PostgreSQL Server ----"
sudo apt-get install postgresql postgresql-server-dev-all -y

echo "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $USER"

#--------------------------------------------------
# Install python
#--------------------------------------------------

echo "\n--- Installing Python 3 + pip3 --"
sudo apt install python3.12 python3.12-dev python3.12-venv python3.12-pip -y

#--------------------------------------------------
# Create odoo user and log path
#--------------------------------------------------

echo "\n---- Create odoo system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$HOME --gecos '$USER' --group $USER
#The user should also be added to the sudo'ers group.
sudo adduser $USER sudo

echo "\n---- Create Log directory ----"
sudo mkdir /var/log/$USER
sudo chown -R $USER:$USER /var/log/$USER
sudo chmod -R 700 /var/log/$USER

#--------------------------------------------------
# Install odoo
#--------------------------------------------------

echo "\n==== Installing ODOO Server ===="
sudo git clone https://www.github.com/odoo/odoo --depth 1 --branch $VERSION $HOME

if [ "$ENTERPRISE" = "True" ]; then
    echo "\n==== Installing ODOO Server ===="

    sudo mkdir $HOME/enterprise
    sudo mkdir $HOME/enterprise/addons

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $VERSION https://www.github.com/odoo/enterprise "$HOME/enterprise/addons" 2>&1)
    while [ $GITHUB_RESPONSE == *"Authentication"* ]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $VERSION https://www.github.com/odoo/enterprise "$HOME/enterprise/addons" 2>&1)
    done

    ADDONSPATH="$ADDONSPATH,${HOME}/enterprise/addons"

    echo "\n---- Added Enterprise code under $HOME/enterprise/addons ----"
fi

echo "\n---- Create custom module directory ----"
sudo mkdir -p $HOME/custom-addons

echo "\n---- Setting permissions on home folder ----"
sudo chown -R $USER:$USER $HOME/*
sudo chown -R $USER:$USER $HOME
sudo chmod -R 700 $HOME/*
sudo chmod -R 700 $HOME

echo "* Create server config file"

# Modify the file below as required for your configuration
sudo cat <<EOF > /etc/${CONFIG}.conf
[options]
admin_passwd = ${SUPERADMIN}
db_host = False
db_port = False
db_user = ${USER}
db_password = False
addons_path = ${ADDONSPATH}
log_file = /var/log/$USER/odoo.log
EOF

sudo chown $USER:$USER /etc/${CONFIG}.conf
sudo chmod 640 /etc/${CONFIG}.conf

#--------------------------------------------------
# Install dependencies
#--------------------------------------------------

if [ "$VENV" = "True" ]; then
    echo "Installing dependencies in virtual environment"
    python3.12 -m venv $HOME/$USER-venv
    . $HOME/$USER-venv/bin/activate

    # Add venv to EXECSTART
    EXECSTART="$HOME/$USER-venv/bin/python3.12 $EXECSTART"
else
    echo "Installing dependencies"
fi

# These packages are for odoo 17.0 - UPDATE IF NOT USING 17.0
sudo apt install build-essential wget git libfreetype-dev libxml2-dev libzip-dev libsasl2-dev node-less libjpeg-dev zlib1g-dev libpq-dev libxslt1-dev libldap2-dev libtiff5-dev libopenjp2-7-dev libcap-dev -y
sudo apt install wkhtmltopdf -y

echo "\n---- Install python packages/requirements ----"

if [ "$VENV" = "True" ]; then
    $HOME/$USER-venv/bin/pip install wheel setuptools pip --upgrade
    $HOME/$USER-venv/bin/pip install -r ${HOME}/requirements.txt
else
    sudo pip3 install wheel setuptools pip --upgrade
    sudo pip3 install -r ${HOME}/requirements.txt
fi

if [ "$VENV" = "True" ]; then
    deactivate
fi

#--------------------------------------------------
# Create service for odoo
#--------------------------------------------------

echo "Creating odoo service"
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
ExecStart=${EXECSTART}
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
echo "Starting odoo"
sudo systemctl enable --now ${CONFIG}
sudo systemctl restart ${CONFIG}
sudo systemctl daemon-reload
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
echo "Code location: $HOME"
echo "Password superadmin (database): $SUPERADMIN"
echo "Start Odoo service: sudo systemctl enable --now $CONFIG"
echo "Stop Odoo service: sudo systemctl disable $CONFIG"
echo "Restart Odoo service: sudo systemctl restart $CONFIG"
echo "-----------------------------------------------------------"