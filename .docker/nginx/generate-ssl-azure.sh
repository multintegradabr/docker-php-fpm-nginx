#!/bin/sh

exec 1>> /home/LogFiles/execContainer.log 2>&1

echo "Configuring SSL to Nginx"
echo "Copying SSL from Azure"
cp /var/ssl/private/*.p12 /etc/nginx/ssl/ssl.p12

echo "Converting p12 to .pem"
openssl pkcs12 -in /etc/nginx/ssl/ssl.p12 -out /etc/nginx/ssl/ssl.crt.pem -clcerts -nokeys -passin pass:
openssl pkcs12 -in /etc/nginx/ssl/ssl.p12 -out /etc/nginx/ssl/ssl.key.pem -clcerts -nodes -passin pass:
chmod 777 -R /etc/nginx/ssl

echo "Updating nginx config"
ln -sf /home/site/docker/nginx/ssl.conf /etc/nginx/ssl/ssl.conf
ln -sf /home/site/docker/nginx/dhparams.pem /etc/nginx/ssl/dhparams.pem