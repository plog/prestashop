#!/bin/bash

# Function to check if a directory exists
dir_exists() {
    [ -d "$1" ]
}

# Function to check if a file exists
file_exists() {
    [ -f "$1" ]
}

# Function to check if PrestaShop is already installed
prestashop_installed() {
    file_exists /var/www/html/config/settings.inc.php || file_exists /var/www/html/install.lock
}

# Function to extract PrestaShop and copy files
extract_and_copy_prestashop() {
    if ! prestashop_installed; then
        echo -e "* Extracting PrestaShop..."
        folder="/tmp/data-ps"
        mkdir -p $folder
        unzip -n -qq /tmp/prestashop.zip -d $folder >/dev/null 2>&1

        if ! dir_exists "$folder/prestashop"; then
            unzip -n -qq $folder/prestashop.zip -d $folder/prestashop >/dev/null 2>&1
            rm -rf $folder/prestashop.zip
        fi

        chown www-data:www-data -R $folder/prestashop/
        cp -n -R -T -p $folder/prestashop/ /var/www/html
        rm /tmp/prestashop.zip
        echo -e "* Extracting PrestaShop DONE!"
    else
        echo -e "* Prestashop is already there"
    fi
}

# Function to wait for MySQL server startup
wait_for_mysql() {
    local RET=1
    while [ $RET -ne 0 ]; do
        echo -e "* Checking if $DB_SERVER is available..."
        mysql -h $DB_SERVER -P $DB_PORT -u $DB_USER -p$DB_PASSWD -e "status" > /dev/null 2>&1
        RET=$?

        if [ $RET -ne 0 ]; then
            echo -e "* Waiting for confirmation of MySQL service startup";
            sleep 5
        fi
    done
    echo -e "* DB server $DB_SERVER is available, let's continue!"
}

# Function to run pre-install scripts
run_pre_install_scripts() {
    if dir_exists "/tmp/pre-install-scripts/"; then
        echo -e "* Running pre-install script(s)..."
        for script in /tmp/pre-install-scripts/*; do
            [ -f "$script" ] && "$script"
        done
    else
        echo -e "* No pre-install script found, let's continue..."
    fi
}

# Main script starts here

# Extract PrestaShop and copy files if not already installed
if ! prestashop_installed; then
    extract_and_copy_prestashop
fi

# Check if DB_SERVER is defined for automatic installation
if [ "$DB_SERVER" = "<to be defined>" ] && [ $PS_INSTALL_AUTO = 1 ]; then
    echo >&2 'error: You requested automatic PrestaShop installation but MySQL server address is not provided'
    echo >&2 '  You need to specify DB_SERVER in order to proceed'
    exit 1
elif [ "$DB_SERVER" != "<to be defined>" ] && [ $PS_INSTALL_AUTO = 1 ]; then
    wait_for_mysql
fi

# Stop at errors
set -e

# Check if PrestaShop core is already installed
if ! prestashop_installed; then
    echo -e "* Setting up install lock file..."
    touch ./install.lock
    echo -e "* Reapplying PrestaShop files for enabled volumes ..."

    if dir_exists "/tmp/data-ps/prestashop"; then
        echo -e "* Copying files from tmp directory ..."
        cp -n -R -T -p /tmp/data-ps/prestashop/ /var/www/html
    else
        echo -e "* No files to copy from tmp directory ..."
    fi

    run_pre_install_scripts

    if [ $PS_ERASE_DB = 1 ]; then
        echo -e "* Drop mysql database..."
        echo -e "* Dropping existing database $DB_NAME..."
        mysql -h $DB_SERVER -P $DB_PORT -u $DB_USER -p$DB_PASSWD -e "drop database if exists $DB_NAME;"
    fi

    if [ $PS_INSTALL_DB = 1 ]; then
        echo -e "* Create mysql database..."
        echo -e "* Creating database $DB_NAME..."
        mysqladmin -h $DB_SERVER -P $DB_PORT -u $DB_USER create $DB_NAME -p$DB_PASSWD --force
    fi

    if [ $PS_INSTALL_AUTO = 1 ]; then
        echo -e "* Installing PrestaShop, this may take a while ..."

        if [ "$PS_DOMAIN" = "<to be defined>" ]; then
            export PS_DOMAIN=$(hostname -i)
        fi

        echo -e "* Launching the installer script..."
        runuser -g www-data -u www-data -- php -d memory_limit=-1 /var/www/html/install/index_cli.php \
        --domain="$PS_DOMAIN" --db_server=$DB_SERVER:$DB_PORT --db_name="$DB_NAME" --db_user=$DB_USER \
        --db_password=$DB_PASSWD --prefix="$DB_PREFIX" --firstname="John" --lastname="Doe" \
        --password=$ADMIN_PASSWD --email="$ADMIN_MAIL" --language=$PS_LANGUAGE --country=$PS_COUNTRY \
        --all_languages=$PS_ALL_LANGUAGES --newsletter=0 --send_email=0 --ssl=$PS_ENABLE_SSL

        if [ $? -ne 0 ]; then
            echo 'warning: PrestaShop installation failed.'
        else
            echo -e "* Removing install folder..."
            rm -r /var/www/html/install/
        fi
    fi

    echo -e "* Setup completed, removing lock file..."
    rm ./install.lock

else
    echo -e "* PrestaShop Core already installed..."
fi

# Enable DEMO mode if required
if [ $PS_DEMO_MODE -ne 0 ]; then
    echo -e "* Enabling DEMO mode ..."
    sed -ie "s/define('_PS_MODE_DEMO_', false);/define('_PS_MODE_DEMO_',\ true);/g" /var/www/html/config/defines.inc.php
fi

# Run init scripts
if dir_exists "/tmp/init-scripts/"; then
    for script in /tmp/init-scripts/*; do
        echo -e "* Running $script"
        [ -f "$script" ] && "$script"
    done
else
    echo -e "* No init script found, let's continue..."
fi

# Rename admin folder if required
if [ "$PS_FOLDER_ADMIN" != "admin" ] && [ -d "/var/www/html/admin" ]; then
    echo -e "* Renaming admin folder as $PS_FOLDER_ADMIN ..."
    mv /var/www/html/admin /var/www/html/$PS_FOLDER_ADMIN/
fi

# Run Apache & SSH
echo -e "* Starting Apache & SSH"
service apache2 start
/usr/sbin/sshd -D
