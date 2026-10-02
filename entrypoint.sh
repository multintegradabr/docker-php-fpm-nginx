#!/bin/bash
# Entrypoint do estágio app. As configs de nginx, php-fpm e supervisor já entram no lugar durante
# o build; aqui fica só o que depende do ambiente. Tudo é idempotente: o container pode reiniciar.

PHP_VERSION="${PHP_VERSION:-8.2}"
LOG_DIR=/home/multi/LogFiles

rm -f "$LOG_DIR"/Laravel-Scheduler.log "$LOG_DIR"/Composer-Updates.log "$LOG_DIR"/OS-Updates.log
mkdir -p "$LOG_DIR"

export TERM=xterm-256color
cat >/etc/motd <<EOL
PHP version : $(php -v | head -n 1 | cut -d ' ' -f 2)
-------------------------------------------------------------------------------------------------
ATENÇÃO: use o usuário 'multi' para operar o php e o supervisor ('su multi'). Para elevar, 'sudo'.
-------------------------------------------------------------------------------------------------
EOL
cat /etc/motd

# Azure App Service: opcache de produção.
if [[ "$WEBSITE_HOSTNAME" == *"azurewebsites.net"* ]]; then
    echo "Running on Azure App Service"
    # Arquivo próprio: o 10-opcache.ini do Ubuntu é symlink para o .ini que carrega a extensão, e
    # sobrescrevê-lo desligaria o opcache.
    cp -f /usr/local/docker/php/php-fpm/opcache.ini "/etc/php/${PHP_VERSION}/fpm/conf.d/99-opcache-prod.ini"
else
    echo "Local Running"
fi

if [ "$DATADOG_ENABLE" = true ] && [ -z "${DD_API_KEY:-}" ]; then
    echo "AVISO: DATADOG_ENABLE=true sem DD_API_KEY — o agente do Datadog NÃO será instalado."
elif [ "$DATADOG_ENABLE" = true ]; then
    echo "Installing Datadog Agent"
    mkdir -p /opt/datadog/
    /bin/bash /usr/local/docker/startup/install-datadog-agent.sh
fi

if [ -n "${GH_TOKEN:-}" ]; then
    echo "Update Git credentials"
    sudo -u multi -E gh auth setup-git
    sudo -u multi git config --global --add safe.directory /var/www
fi

if [ -f /var/www/artisan ]; then
    echo "Laravel app found: configuring workers and running post-init"
    cp -f /usr/local/docker/supervisor/laravel-workers.conf /etc/supervisor/conf.d/laravel-workers.conf
    /bin/bash /usr/local/docker/startup/laravel-post-init.sh >> "$LOG_DIR/Post-Init-App.log" 2>&1
    rm -f /var/www/storage/logs/*
else
    echo "Laravel app is not installed, laravel workers will not be configured"
fi

chown -R multi:multi /home/multi/

echo "Add jobs on crontab"
crontab -u multi /usr/local/docker/cron/crontab

if [ -d /home/multi/startup.d ]; then
    for f in /home/multi/startup.d/*.sh; do
        echo "Executing $f"
        . "$f"
    done
fi

echo "Starting cron"
service cron start

echo "Starting supervisord"
exec supervisord -c /etc/supervisor/supervisord.conf
