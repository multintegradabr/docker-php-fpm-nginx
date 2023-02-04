#!/bin/sh

# Remove old log files
rm -rf /home/LogFiles/execContainer.log
rm -rf /home/LogFiles/cron.log

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
    rm -rf /home/site/docker
    mv -vf /var/www/docker /home/site/
    echo "Link php opcache config file"
    ln -sfn /home/site/docker/php/php-fpm/opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini

    echo "Verifing if Laravel app is installed"
    if [ -f /home/site/wwwroot/artisan ]; then
        echo "Laravel app is already installed"
        echo "Configure Laravel workers in supervisor"
        ln -sf /home/site/docker/supervisor/laravel-workers.ini /etc/supervisor.d/laravel-workers.ini
    else
        echo "Laravel app is not installed, laravel workers will not be configured"
    fi

    if [ -z ${GH_TOKEN+x}]; then
    echo "Update Git credentials"
    cd /home/site & gh auth setup-git
    fi
    
else
    echo "Running on local"
    mkdir -p /home/site/wwwroot
    mv -vf /var/www/docker /home/site/
fi

echo "Link nginx config files"
ln -sfn /home/site/docker/nginx/nginx.conf /etc/nginx/nginx.conf
ln -sfn /home/site/docker/nginx/default.conf /etc/nginx/http.d/default.conf

echo "Link php-fpm config files"
rm /usr/local/etc/php-fpm.d/zz-docker.conf
ln -sfn /home/site/docker/php/php-fpm/custom.ini /usr/local/etc/php/conf.d/custom.ini
ln -sfn /home/site/docker/php/php-fpm/www.conf /usr/local/etc/php-fpm.d/www.conf

echo "Add jobs on crontab"
crontab /home/site/docker/cron/crontab

echo "link supervisor file"
mkdir -p /etc/supervisor.d
ln -sfn /home/site/docker/supervisor/supervisord.ini /etc/supervisor.d/supervisord.ini

echo "Starting services..."

echo "Starting SSH server"
/usr/sbin/sshd

echo "Starting cron"
crontab -l
 
echo "Starting supervisord"
supervisord -c /etc/supervisord.conf