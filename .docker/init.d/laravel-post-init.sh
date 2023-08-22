#!/bin/sh

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