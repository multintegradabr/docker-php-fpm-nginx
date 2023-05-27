#!/bin/bash

# Remove old log files
rm -rf /home/LogFiles/Scheduler.log
rm -rf /home/LogFiles/Updates.log
rm -rf /home/LogFiles/RenewSSL.log
rm -rf /home/LogFiles/UpdateRepo.log

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

eval $(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)

if [[ "$WEBSITE_HOSTNAME" == *"azurewebsites.net"* ]]; then
    echo "Running on Azure App Service"
    rm -rf /home/site/docker
    mv -vf /var/www/docker /home/site/

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
    ln -sfn /home/site/docker/php/php-fpm/opcache.ini /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini
   
else
    echo "Running on local"
    mkdir -p /home/site/wwwroot
    mv -vf /var/www/docker /home/site/
fi

echo "Verifing if Git token are set"
if [ -z ${GH_TOKEN+x}]; then
    echo "GH_TOKEN not seted"
else
    echo "Update Git credentials"
    cd /home/site & gh auth setup-git
git config --global --add safe.directory /home/site/wwwroot
fi

echo "Link php-fpm config files"
ln -sfn /home/site/docker/php/php-fpm/custom.ini /usr/local/etc/php/conf.d/custom.ini

echo "Add jobs on crontab"
crontab /home/site/docker/cron/crontab

echo "link supervisor files"

echo "Verifing if Laravel app is installed"
if [ -f /home/site/wwwroot/artisan ]; then
    echo "Laravel app is already installed"
    echo "Configure Laravel workers in supervisor"
    ln -sfn /home/site/docker/supervisor/laravel-workers.conf /etc/supervisor/conf.d/laravel-workers.conf
else
    echo "Laravel app is not installed, laravel workers will not be configured"
    echo "Install Laravel app using /home/site/docker/run.d/install-laravel-app.sh"
fi
ln -sfn /home/site/docker/supervisor/unit.conf /etc/supervisor/conf.d/unit.conf

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

echo "Starting SSH..."
service ssh start

echo "Starting cron..."
service cron start

echo "Configuring Unit Http Server..."
unitd --no-daemon --control unix:/var/run/control.unit.sock &
sleep 3
curl -X PUT --data-binary @/home/site/docker/unit/config.json --unix-socket \
    /var/run/control.unit.sock http://localhost/config/ &
sleep 2
pkill unitd

echo "Starting supervisord..."
supervisord -c /etc/supervisor/supervisord.conf