#!/bin/sh
set -e

echo "Starting image-verify service..."
echo "Running as user: $(whoami)"
echo "nginx version: $(nginx -v 2>&1)"

# Start nginx in foreground
exec nginx -g "daemon off;"
