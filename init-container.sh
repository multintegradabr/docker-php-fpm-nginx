#!/bin/sh

# Remove old log files
rm -rf /home/LogFiles/execContainer.log
rm -rf /home/LogFiles/cron.log

cat >/etc/motd <<EOL 
  _____                               
  /  _  \ __________ _________   ____  
 /  /_\  \\___   /  |  \_  __ \_/ __ \ 
/    |    \/    /|  |  /|  | \/\  ___/ 
\____|__  /_____ \____/ |__|    \___  >
        \/      \/                  \/ 
APP SERVICE ON LINUX

PHP version : `php -v | head -n 1 | cut -d ' ' -f 2`
EOL
cat /etc/motd

# Get environment variables to show up in SSH session
eval $(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)

echo "Create folders"
mkdir -p /home/site/wwwroot
mv -vf /var/www/docker /home/site/

echo "Link nginx config files"
ln -sfn /home/site/docker/nginx/nginx.conf /etc/nginx/nginx.conf
ln -sfn /home/site/docker/nginx/default.conf /etc/nginx/http.d/default.conf
nginx stop

echo "Link php-fpm config files"
rm /usr/local/etc/php-fpm.d/zz-docker.conf
ln -sfn /home/site/docker/php/php-fpm/custom.ini /usr/local/etc/php/conf.d/custom.ini
ln -sfn /home/site/docker/php/php-fpm/opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini
ln -sfn /home/site/docker/php/php-fpm/www.conf /usr/local/etc/php-fpm.d/www.conf

echo "Add jobs on crontab"
crontab /home/site/docker/cron/crontab

echo "link supervisor file"
ln -sfn /home/site/docker/supervisor/supervisord.ini /etc/supervisor.d/supervisord.ini

echo "Starting services..."

echo "Starting SSH server"
/usr/sbin/sshd

echo "Starting cron"
crontab -l

echo "Starting supervisord"
supervisord -c /etc/supervisor.d/supervisord.ini