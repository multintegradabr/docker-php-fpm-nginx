#!/bin/sh

echo "Cloning App from GitHub..."

if [ -z ${REPO_NAME+x} ]; then
    echo "REPO_NAME is not defined, set REPO_NAME and try again!"
    echo "exiting..."
    exit 1
else
rm -rf /home/site/wwwroot/*
cd /home/site/wwwroot & gh repo clone $REPO_NAME . -- --branch main
fi

echo "Installing Laravel App..."

echo "Install Laravel dependencies"
cd /home/site/wwwroot & composer install --no-dev --prefer-dist --optimize-autoloader

if [ -f /home/site/wwwroot/.env ]; then
    echo "Laravel .env file already exists"
else
    echo "Laravel .env file does not exist, creating one"
    cp /home/site/wwwroot/.env.example /home/site/wwwroot/.env
fi

echo "Generate Laravel key"
php artisan key:generate

echo "Migrate Laravel database"
php artisan migrate

echo "Update seeders"
php artisan db:seed

echo "Enable storage link"
php artisan storage:link

echo "Update Laravel storage permissions"
chmod -R 777 /home/site/wwwroot/storage

echo "Update Laravel bootstrap/cache permissions"
chmod -R 777 /home/site/wwwroot/bootstrap/cache

echo "Finished Laravel App installation"