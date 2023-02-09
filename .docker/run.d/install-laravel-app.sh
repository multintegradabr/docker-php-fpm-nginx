#!/bin/sh

echo "Cloning App from GitHub..."

if [ -z ${REPO_NAME+x} ]; then
    echo "REPO_NAME is not defined, set REPO_NAME and try again!"
    echo "exiting..."
    exit 1
else
    if [ -d "/home/site/wwwroot/.git" ]; then
        echo "Git folder already exists, skipping clone"
    else
        echo "Git folder does not exist, cloning repo"
        cd /home/site/wwwroot & gh repo clone $REPO_NAME . -- --branch $REPO_BRANCH
    fi
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
chmod -R 777 /home/site/wwwroot/storage

echo "Update Laravel bootstrap/cache permissions"
chmod -R 777 /home/site/wwwroot/bootstrap/cache

echo "Install npm dependencies"
npm install -g npm
npm install
if [ $? -ne 0 ]; then
    echo "npm install failed, exiting..."
    exit 1
fi
echo "Build npm assets"
npm run dev

supervisorctl restart all

echo "Finished Laravel App installation"