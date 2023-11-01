#!/bin/sh
while true; do
    php /var/www/artisan schedule:run >> /home/multi/LogFiles/Laravel-Scheduler.log 2>&1
    sleep 60
done
