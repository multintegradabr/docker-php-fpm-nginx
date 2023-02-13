#!/bin/sh

if [ "$AUTO_DEPLOY_ENABLE" != "true" ]; then
    echo "Auto Deploy is disabled. Skipping..."
    exit 0
fi

cd /home/site/wwwroot

echo "Fetching updates from remote repository..."
git fetch $REPO_NAME

echo "Checking for updates..."
if [ $(git rev-parse HEAD) != $(git rev-parse $REPO_NAME/$REPO_BRANCH) ]; then
  echo "New updates found. Updating..."
  git merge $REPO_NAME/$REPO_BRANCH
  echo "Repository updated successfully."

  echo "Updating Laravel App..."
  composer install --no-dev --prefer-dist --optimize-autoloader
  php artisan migrate --force
  php artisan db:seed --force
else
  echo "No updates found."
fi
