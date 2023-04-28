#!/bin/bash

cd /home/site/wwwroot

echo "Installing Datadog Agent"
export DD_HOSTNAME=$WEBSITE_SITE_NAME
DD_API_KEY=4190390b821cd76e0f809161f3386d3a DD_SITE="datadoghq.com" DD_INSTALL_ONLY=true bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"

echo "Configuring Datadog Agent"
mv /etc/datadog-agent/security-agent.yaml.example security-agent.yaml 

echo "Starting Datadog Agent"
service datadog-agent start

echo "Configuring PHP Tracing Extension"
curl -LO https://github.com/DataDog/dd-trace-php/releases/latest/download/datadog-setup.php

php datadog-setup.php --php-bin=all --enable-appsec --enable-profiling

rm datadog-setup.php