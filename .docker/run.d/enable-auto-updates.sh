#!/bin/sh

echo "Enabling auto updates after merge..."

mv /home/site/run.d/post-merge /home/site/wwwroot/.git/hooks/post-merge

echo "Successfully enabled auto updates after merge!"