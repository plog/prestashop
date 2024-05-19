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

        # Enable debug mode and force compile, disable cache
        CONFIG_FILE="/var/www/html/config/defines.inc.php"
        sed -i "s/define('_PS_MODE_DEV_', false);/define('_PS_MODE_DEV_', true);/" $CONFIG_FILE
        sed -i "s/define('_PS_DEBUG_PROFILING_', false);/define('_PS_DEBUG_PROFILING_', false);/" $CONFIG_FILE
        sed -i "s/define('_PS_SMARTY_FORCE_COMPILE_', false);/define('_PS_SMARTY_FORCE_COMPILE_', true);/" $CONFIG_FILE
        sed -i "s/define('_PS_SMARTY_CACHE_', true);/define('_PS_SMARTY_CACHE_', false);/" $CONFIG_FILE
        
        mysql -h $DB_SERVER -P $DB_PORT -u $DB_USER -p$DB_PASSWD $DB_NAME <<EOF
UPDATE ${DB_PREFIX}configuration SET value = '2' WHERE name = 'PS_SMARTY_FORCE_COMPILE';
UPDATE ${DB_PREFIX}configuration SET value = '0' WHERE name = 'PS_SMARTY_CACHE';
UPDATE ${DB_PREFIX}configuration SET value = '1' WHERE name = 'PS_DEV_MODE';
EOF
        if [ $? -ne 0 ]; then
            echo '-----> PrestaShop installation failed. <-------'
        fi
    fi

    echo -e "* Setup completed, removing lock file..."
    rm ./install.lock

else
    echo -e "* PrestaShop Core already installed..."
fi

# Rename admin folder and delete install
echo -e "* Admin folder ($PS_FOLDER_ADMIN), removing install, activate debug,..."
mv /var/www/html/admin /var/www/html/$PS_FOLDER_ADMIN/
# Path to admin index.php
ADMIN_INDEX="/var/www/html/$PS_FOLDER_ADMIN/index.php"
sed -i "/Debug::enable();/a\    ini_set('error_reporting', E_ALL \& ~E_NOTICE \& ~E_DEPRECATED & ~E_WARNING);" $ADMIN_INDEX

rm -r /var/www/html/install/

# XDebug & Some more debug features
sed -i "s/xdebug.remote_enable=0/xdebug.remote_enable=1/" /usr/local/etc/php/php.ini
echo '<?php phpinfo(); ?>' > /var/www/html/i.php
cat <<EOF >> /usr/local/etc/php/php.ini
[XDebug]
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.mode=debug
xdebug.start_with_request=yes
xdebug.discover_client_host=no
xdebug.log_level=2
EOF

chown -R www-data:www-data /var/log/apache2
chown -R www-data:www-data /var/www/html

# Run Apache & SSH
echo -e "* Starting Apache & SSH"
service apache2 start

/usr/sbin/sshd -D
