#!/bin/sh
# Start the queue worker in the background
php artisan queue:work redis --sleep=3 --tries=3 --max-time=3600 &

# Start Octane in the foreground (serves health checks on port 8080)
php artisan octane:frankenphp --port=8080 --host=0.0.0.0
