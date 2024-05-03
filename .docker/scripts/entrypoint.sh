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


#Configure files for Azure App Service or Local
if [[ "$WEBSITE_HOSTNAME" == *"azurewebsites.net"* ]]; then
    echo "Running on Azure App Service"
    
    echo "Setting php opcache config file"
    mv -vf /usr/local/docker/php/php-fpm/opcache.ini /etc/php/8.2/fpm/conf.d/10-opcache.ini
  
else
    echo "Local Running"


fi

# Configure Datadog
if [ "$DATADOG_ENABLE" = true ]; then
    echo "Installing Datadog Agent"
    mkdir -p /opt/datadog/
    chmod +x /usr/local/docker/scripts/install-datadog-agent.sh
    sudo /bin/bash /usr/local/docker/scripts/install-datadog-agent.sh
fi

# Configure Git credentials
echo "Verifing if Git token are set"
if [ -z ${GH_TOKEN+x}]; then
    echo "GH_TOKEN not defined, skipping Git credentials update"
else
    echo "Update Git credentials"
    cd /home/multi & gh auth setup-git
git config --global --add safe.directory /home/multi
fi

# Configure files for php
echo "Setting php-fpm config files"
mv -vf /usr/local/docker/php/www.conf /etc/php/8.2/fpm/pool.d/www.conf
mv -vf /usr/local/docker/php/custom.ini /etc/php/8.2/fpm/conf.d/custom.ini

# Configure files for nginx
echo "Setting nginx config files"
mv -vf /usr/local/docker/nginx/default.conf /etc/nginx/sites-enabled/default

# Configure files for supervisor
echo "Setting supervisor file"
mv -vf /usr/local/docker/supervisor/app-services.conf /etc/supervisor/conf.d/app-services.conf

echo "Verifing if Laravel app is installed"
if [ -f /var/www/artisan ]; then
    echo "Laravel app is already installed"
    echo "Configure Laravel scheduler job and workers in supervisor"
    mv -vf /usr/local/docker/supervisor/laravel-workers.conf /etc/supervisor/conf.d/laravel-workers.conf
    crontab -u multi -l | cat - /usr/local/docker/cron/crontab | crontab -u multi -
    
    chmod +x /usr/local/docker/scripts/laravel-post-init.sh
    echo "Execute Laravel post init script"
    /bin/bash /usr/local/docker/scripts/laravel-post-init.sh >> /home/multi/LogFiles/Post-Init-App.log 2>&1
    rm /var/www/storage/logs/*
else
    echo "Laravel app is not installed, laravel scheduler and workers will not be configured"

fi

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

echo "Starting supervisor"
supervisord -c /etc/supervisor/supervisord.conf