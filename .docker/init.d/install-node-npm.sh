#!/bin/sh

exec 1>> /home/LogFiles/execContainer.log 2>&1

echo "Installing Node!"
apk add nodejs npm