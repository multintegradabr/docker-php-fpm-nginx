#!/bin/sh

if [ "$AUTO_DEPLOY_ENABLE" != "true" ]; then
    echo "Auto Deploy is disabled. Skipping..."
    exit 0
fi

cd /home/site/wwwroot

echo "Fetching updates from remote repository..."
git fetch origin

echo "Checking for updates..."
if [ $(git rev-parse HEAD) != $(git rev-parse origin/$REPO_BRANCH) ]; then
  echo "New updates found. Updating..."
  git merge origin/$REPO_BRANCH
  echo "Repository updated successfully."
  echo "Restarting application..."
  supervisorctl restart all
  echo "Application restarted successfully."

  echo "Updating Laravel App..."
  composer install --no-dev --prefer-dist --optimize-autoloader
  php artisan migrate --force
  php artisan db:seed --force

  echo "Updating NPM Packages..."
  npm install -G npm
  npm install
  npm run production
else
  echo "No updates found."
fi
