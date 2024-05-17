#!/bin/sh
#
# This is an init-script for prestashop-flashlight.
#
# Storing a folder in /var/www/html/modules is not enough to register the module
# into PrestaShop, hence why we have to call the console install CLI.
#

cd "$PS_FOLDER"
echo "* [testmodule] installing the module... PS folder : $PS_FOLDER"
# php -d memory_limit=-1 bin/console prestashop:module --no-interaction install "demosymfonyformsimple"