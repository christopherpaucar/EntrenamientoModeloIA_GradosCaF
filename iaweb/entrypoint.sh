#!/bin/sh
set -e

# Wait for DB if using Postgres (simple loop, optional)
if [ -n "$POSTGRES_HOST" ]; then
  echo "Waiting for Postgres at $POSTGRES_HOST:$POSTGRES_PORT..."
  until nc -z $POSTGRES_HOST $POSTGRES_PORT; do
    echo "Postgres not available yet, sleeping 1s"
    sleep 1
  done
fi

echo "Apply database migrations (if any)"
python manage.py migrate --noinput

echo "Collect static files"
python manage.py collectstatic --noinput

echo "Starting Gunicorn"
# Use fewer workers in small/low-memory environments to avoid OOM; allow override with env vars
GUNICORN_WORKERS=${GUNICORN_WORKERS:-1}
GUNICORN_TIMEOUT=${GUNICORN_TIMEOUT:-120}
exec gunicorn iaweb.wsgi:application --bind 0.0.0.0:8000 --workers ${GUNICORN_WORKERS} --timeout ${GUNICORN_TIMEOUT}
