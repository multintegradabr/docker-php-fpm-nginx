#!/bin/bash

if [ "$AUTO_DEPLOY_ENABLE" = true ]; then

cd /home/site/wwwroot

if [ -d "/home/site/wwwroot/.git" ]; then
  echo "Fetching updates from remote repository..."
  git fetch origin

  echo "Checking for updates..."
    if [ $(git rev-parse HEAD) != $(git rev-parse origin/$REPO_BRANCH) ]; then
    echo "New updates found. Updating..."
    git restore .
    git pull origin $REPO_BRANCH
    echo "Repository updated successfully."

    echo "Updating Laravel App..."
    
    echo "Fixing folders permissions"
    chmod -R 777 -R vendor
    chmod -R 777 storage bootstrap/cache
    
    echo "Updating composer packages..."
    composer install

    #echo "Updating database..."
    #php artisan migrate --force
    #echo "Database updated successfully."
    
    #echo "Seeding database..."
    #php artisan db:seed --force
    #echo "Database seeded successfully."

    echo "Laravel App updated successfully."

    echo "Updating NPM Packages..."
    npm install -G npm
    npm install
    npm run production

    echo "Restarting application..."
    supervisorctl restart all
    echo "Application restarted successfully."
      
    else
      echo "No updates found."
    fi  
else
  echo "Git folder does not exist, exiting"
  exit 0
fi

else
  echo "Auto deploy is disabled, exiting"
  exit 0
fi
```