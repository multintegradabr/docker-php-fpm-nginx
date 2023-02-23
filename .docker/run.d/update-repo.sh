#!/bin/sh

if [ "$AUTO_DEPLOY_ENABLE" != "true" ]; then
    echo "Auto Deploy is disabled. Skipping..."
    exit 0
fi

cd /home/site/wwwroot

if [ -d "/home/site/wwwroot/.git" ]; then
  echo "Fetching updates from remote repository..."
  git fetch origin

  echo "Checking for updates..."
    if [ $(git rev-parse HEAD) != $(git rev-parse origin/$REPO_BRANCH) ]; then
    echo "New updates found. Updating..."
    git merge origin/$REPO_BRANCH
    echo "Repository updated successfully."

    echo "Updating Laravel App..."
    
    echo "Updating composer packages..."
    composer install --no-dev

    echo "Updating database..."
    #php artisan migrate --force
    #echo "Database updated successfully."
    
    #echo "Seeding database..."
    #php artisan db:seed --force
    #echo "Database seeded successfully."

    echo "Laravel App updated successfully."

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
