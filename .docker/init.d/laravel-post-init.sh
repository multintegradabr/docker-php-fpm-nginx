#!/bin/bash

if [ -f "artisan" ]; then

    echo "Migrate Laravel database"
    sudo -E -u www-data php artisan migrate --force
    if [ $? -ne 0 ]; then
        echo "migrate failed"
    fi

    echo "Update seeders"
    sudo -E -u www-data php artisan db:seed --force
    if [ $? -ne 0 ]; then
        echo "db:seed failed"
    fi

    echo "Enable storage link"
    sudo -E -u www-data php artisan storage:link
    if [ $? -ne 0 ]; then
        echo "storage:link failed"
    fi

else
    echo "Not a Laravel application. Skipping Laravel post init commands."
fi