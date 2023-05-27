#!/bin/bash

echo "Cloning App from GitHub..."

if [ -z ${REPO_NAME+x} ]; then
    echo "REPO_NAME is not defined, set REPO_NAME and try again!"
    echo "exiting..."
    exit 1
else
    if [ -d "/var/www/app/.git" ]; then
        echo "Git folder already exists, skipping clone"
    else
        echo "Git folder does not exist, cloning repo"
        cd /var/www/app & gh repo clone $REPO_NAME . -- --branch $REPO_BRANCH
    fi
fi

echo "Installing Laravel App..."

echo "Install Laravel dependencies"
cd /var/www/app & composer install --no-dev --prefer-dist --optimize-autoloader

if [ -f /var/www/app/.env ]; then
    echo "Laravel .env file already exists"
else
    echo "Laravel .env file does not exist, creating one"
    cp /var/www/app/.env.example /var/www/app/.env
fi

echo "Generate Laravel key"
php artisan key:generate
if [ $? -ne 0 ]; then
    echo "key:generate failed, exiting..."
    exit 1
fi

echo "Migrate Laravel database"
php artisan migrate --force
if [ $? -ne 0 ]; then
    echo "migrate failed, exiting..."
    exit 1
fi

echo "Update seeders"
php artisan db:seed InitSeeder --force
if [ $? -ne 0 ]; then
    echo "db:seed failed, exiting..."
    exit 1
fi

echo "Enable storage link"
php artisan storage:link
if [ $? -ne 0 ]; then
    echo "storage:link failed, exiting..."
    exit 1
fi

echo "Update Laravel storage permissions"
chmod -R 777 /var/www/app/storage

echo "Update Laravel bootstrap/cache permissions"
chmod -R 777 /var/www/app/bootstrap/cache

echo "Install npm dependencies"
npm install -g npm
npm install
if [ $? -ne 0 ]; then
    echo "npm install failed, exiting..."
    exit 1
fi
echo "Run npm "
npm run dev

supervisorctl restart all

echo "Finished Laravel App installation"