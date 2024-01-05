#!/bin/bash

# Remove old log files
rm -rf /home/multi/LogFiles/Laravel-Scheduler.log
rm -rf /home/multi/LogFiles/Composer-Updates.log
rm -rf /home/multi/LogFiles/OS-Updates.log
rm -rf /home/multi/LogFiles/RenewSSL.log

#Set term
export TERM=xterm-256color
cat >/etc/motd <<EOL 
 ___ ___  __ __  _     ______  ____  ____   ______    ___   ____  ____    ____  ___     ____ 
|   |   ||  |  || |   |      ||    ||    \ |      |  /  _] /    ||    \  /    ||   \   /    |
| _   _ ||  |  || |   |      | |  | |  _  ||      | /  [_ |   __||  D  )|  o  ||    \ |  o  |
|  \_/  ||  |  || |___|_|  |_| |  | |  |  ||_|  |_||    _]|  |  ||    / |     ||  D  ||     |
|   |   ||  :  ||     | |  |   |  | |  |  |  |  |  |   [_ |  |_ ||    \ |  _  ||     ||  _  |
|   |   ||     ||     | |  |   |  | |  |  |  |  |  |     ||     ||  .  \|  |  ||     ||  |  |
|___|___| \__,_||_____| |__|  |____||__|__|  |__|  |_____||___,_||__|\_||__|__||_____||__|__|
                      A P P   S E R V I C E   O N   L I N U X
PHP version : `php -v | head -n 1 | cut -d ' ' -f 2`
___________________________________________________________________________________________________________________
ATENÇÃO: sempre utilize o usuário 'multi' para realizar operações no php e supervisor por exemplo, altere o usuário
usando o comando: 'su multi', se precisar de elevação, como a instalação de um pacote, use 'sudo <comando>'
-------------------------------------------------------------------------------------------------------------------
EOL
cat /etc/motd

# Get environment variables to show up in SSH session
eval $(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)

echo "Create Logs folder"
mkdir -p /home/multi/LogFiles

#Configure files for Azure App Service
if [[ "$WEBSITE_HOSTNAME" == *"azurewebsites.net"* ]]; then
    echo "Running on Azure App Service"
    
    echo "Setting php opcache config file"
    mkdir -p /usr/local/etc/php/conf.d
    mv -vf /usr/local/docker/php/php-fpm/opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini

    if [ "$DATADOG_ENABLE" = true ]; then
    echo "Installing Datadog Agent"
    mkdir -p /opt/datadog/
    chmod +x /usr/local/docker/startup/install-datadog-agent.sh
    sudo /bin/bash /usr/local/docker/startup/install-datadog-agent.sh
    fi
   
else
    echo "Local Running"

    if [ "$DATADOG_ENABLE" = true ]; then
    echo "Installing Datadog Agent"
    mkdir -p /opt/datadog/
    chmod +x /usr/local/docker/startup/install-datadog-agent.sh
    sudo /bin/bash /usr/local/docker/startup/install-datadog-agent.sh
    fi
fi

# Configure Git credentials
echo "Verifing if Git token are set"
if [ -z ${GH_TOKEN+x}]; then
    echo "GH_TOKEN not seted"
else
    echo "Update Git credentials"
    cd /home/multi & gh auth setup-git
git config --global --add safe.directory /var/www
fi

# Configure files for nginx
echo "Setting nginx config files"
mv -vf /usr/local/docker/nginx/nginx.conf /etc/nginx/nginx.conf
rm /etc/nginx/sites-enabled/default
mv -vf /usr/local/docker/nginx/default.conf /etc/nginx/sites-enabled/default.conf

# Configure files for php
echo "Setting php-fpm config files"
rm /usr/local/etc/php-fpm.d/zz-docker.conf
rm /usr/local/etc/php-fpm.d/docker.conf
mv -vf /usr/local/docker/php/php-fpm/php-fpm.conf /usr/local/etc/php-fpm.conf
mv -vf /usr/local/docker/php/php-fpm/www.conf /usr/local/etc/php-fpm.d/www.conf
mv -vf /usr/local/docker/php/php-fpm/custom.ini /usr/local/etc/php/conf.d/custom.ini
rm -r /var/www/html

# Fix permissions in multi folder after changes
sudo chown -R multi:multi /home/multi/

# Fix permission for cron script
sudo chmod +x /usr/local/docker/cron/php-schedule.sh

# Configure files for supervisor
echo "Setting supervisor file"

echo "Verifing if Laravel app is installed"
if [ -f /var/www/artisan ]; then
    echo "Laravel app is already installed"
    echo "Configure Laravel workers in supervisor"
    mv -vf /usr/local/docker/supervisor/laravel-workers.conf /etc/supervisor/conf.d/laravel-workers.conf
    chmod +x /usr/local/docker/startup/laravel-post-init.sh
    /bin/bash /usr/local/docker/startup/laravel-post-init.sh >> /home/multi/LogFiles/Post-Init-App.log 2>&1
    rm /var/www/storage/logs/*
else
    echo "Laravel app is not installed, laravel workers will not be configured"
fi
mv -vf /usr/local/docker/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
mv -vf /usr/local/docker/supervisor/php-nginx.conf /etc/supervisor/conf.d/php-nginx.conf

# Configure files for cron
echo "Add jobs on crontab"
crontab -u multi /usr/local/docker/cron/crontab

# Execute custom scripts
echo "Execute custom scripts"
if [ -d "/home/multi/startup.d" ]; then
    echo "Custom scripts found"
    for f in /home/multi/startup.d/*.sh; do
    echo "Executing $f"
    . "$f"
done
else
    echo "Custom scripts not found"
fi

echo "Starting services..."

echo "Starting SSH server"
service ssh start

echo "Starting cron"
service cron start

echo "Starting supervisord"
supervisord -c /etc/supervisor/supervisord.conf