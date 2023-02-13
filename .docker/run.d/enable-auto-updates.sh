#!/bin/sh

echo "Enabling auto updates after merge..."

mv /home/site/run.d/post-merge /home/site/wwwroot/.git/hooks/post-merge
mv /home/site/run.d/post-commit /home/site/wwwroot/.git/hooks/post-commit

chmod +x /home/site/wwwroot/.git/hooks/post-merge
chmod +x /home/site/wwwroot/.git/hooks/post-commit

echo "Successfully enabled auto updates after merge and commits."