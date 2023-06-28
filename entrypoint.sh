#!/bin/bash

# Remove old log files
rm -rf /home/LogFiles/Laravel-Scheduler.log
rm -rf /home/LogFiles/Composer-Updates.log
rm -rf /home/LogFiles/OS-Updates.log
rm -rf /home/LogFiles/RenewSSL.log

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
EOL
cat /etc/motd

# Get environment variables to show up in SSH session
eval $(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)


# Configure files for Azure App Service
if [[ "$WEBSITE_HOSTNAME" == *"azurewebsites.net"* ]]; then
    echo "Running on Azure App Service"

    echo "Move custom scripts to docker folder"
    rm -rf /home/site/docker
    mv -vf /tmp/docker /home/site/

    echo "Move custom scripts to run.d folder"
    if [ -d "/home/site/run.d" ]; then
        echo "run.d folder already exists"
    else
        echo "run.d folder does not exist, creating one"
        mkdir -p /home/site/run.d
    fi
    find /home/site/docker/run.d/* -type f -print0 | xargs -0 mv -t /home/site/run.d/
    rm -rf /home/site/docker/run.d  

    echo "Move custom scripts to init.d folder"
    if [ -d "/home/site/init.d" ]; then
        echo "init.d folder already exists"
    else
        echo "init.d folder does not exist, creating one"
        mkdir -p /home/site/init.d
    fi
    find /home/site/docker/init.d/* -type f -print0 | xargs -0 mv -t /home/site/init.d/
    rm -rf /home/site/docker/init.d
    
    echo "Link php opcache config file"
    mkdir -p /usr/local/etc/php/conf.d
    ln -sfn /home/site/docker/php/php-fpm/opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini

    echo "Exporting variables to /etc/environment"
    env >> /etc/environment
   
else
    echo "Running on local"
    mkdir -p /home/site/LogFiles
    mv -vf /tmp/docker /home/site/
fi

# Configure Git credentials
echo "Verifing if Git token are set"
if [ -z ${GH_TOKEN+x}]; then
    echo "GH_TOKEN not seted"
else
    echo "Update Git credentials"
    cd /home/site & gh auth setup-git
git config --global --add safe.directory /var/www
fi

# Configure files for nginx
echo "Link nginx config files"
ln -sfn /home/site/docker/nginx/nginx.conf /etc/nginx/nginx.conf
ln -sfn /home/site/docker/nginx/default.conf /etc/nginx/conf.d/default.conf

# Configure files for php
echo "Link php-fpm config files"
rm /usr/local/etc/php-fpm.d/zz-docker.conf
rm /usr/local/etc/php-fpm.d/www.conf.default
mkdir -p /usr/local/etc/php/php-fpm.d
ln -sfn /home/site/docker/php/php-fpm/custom.ini /usr/local/etc/php/conf.d/custom.ini
ln -sfn /home/site/docker/php/php-fpm/www.conf /usr/local/etc/php-fpm.d/www.conf

# Configure files for cron
echo "Add jobs on crontab"
crontab /home/site/docker/cron/crontab

# Configure files for supervisor
echo "link supervisor file"

echo "Verifing if Laravel app is installed"
if [ -f /var/www/artisan ]; then
    echo "Laravel app is already installed"
    echo "Configure Laravel workers in supervisor"
    ln -sfn /home/site/docker/supervisor/laravel-workers.conf /etc/supervisor/conf.d/laravel-workers.conf
else
    echo "Laravel app is not installed, laravel workers will not be configured"
fi
ln -sfn /home/site/docker/supervisor/php-nginx.conf /etc/supervisor/conf.d/php-nginx.conf

# Execute custom scripts
echo "Execute custom scripts"
if [ -d "/home/site/init.d" ]; then
    echo "Custom scripts found"
    for f in /home/site/init.d/*.sh; do
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