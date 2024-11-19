#!/bin/bash
## Do not modify this file. You will lose the ability to autoupdate!

VERSION="13"
CDN="https://raw.githubusercontent.com/alexseysua/coolify/refs/heads/main"
LATEST_IMAGE=${1:-latest}
LATEST_HELPER_VERSION=${2:-latest}

DATE=$(date +%Y-%m-%d-%H-%M-%S)
LOGFILE="/var/lib/coolify/source/upgrade-${DATE}.log"

curl -fsSL https://raw.githubusercontent.com/alexseysua/coolify/refs/heads/main/docker-compose.yml -o /var/lib/coolify/source/docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/alexseysua/coolify/refs/heads/main/docker-compose.prod.yml -o /var/lib/coolify/source/docker-compose.prod.yml
curl -fsSL https://raw.githubusercontent.com/alexseysua/coolify/refs/heads/main/.env.production -o /var/lib/coolify/source/.env.production

# Merge .env and .env.production. New values will be added to .env
awk -F '=' '!seen[$1]++' /var/lib/coolify/source/.env /var/lib/coolify/source/.env.production  > /var/lib/coolify/source/.env.tmp && mv /var/lib/coolify/source/.env.tmp /var/lib/coolify/source/.env
# Check if PUSHER_APP_ID or PUSHER_APP_KEY or PUSHER_APP_SECRET is empty in /var/lib/coolify/source/.env
if grep -q "PUSHER_APP_ID=$" /var/lib/coolify/source/.env; then
    sed -i "s|PUSHER_APP_ID=.*|PUSHER_APP_ID=$(openssl rand -hex 32)|g" /var/lib/coolify/source/.env
fi

if grep -q "PUSHER_APP_KEY=$" /var/lib/coolify/source/.env; then
    sed -i "s|PUSHER_APP_KEY=.*|PUSHER_APP_KEY=$(openssl rand -hex 32)|g" /var/lib/coolify/source/.env
fi

if grep -q "PUSHER_APP_SECRET=$" /var/lib/coolify/source/.env; then
    sed -i "s|PUSHER_APP_SECRET=.*|PUSHER_APP_SECRET=$(openssl rand -hex 32)|g" /var/lib/coolify/source/.env
fi

# Make sure coolify network exists
# It is created when starting Coolify with docker compose
docker network create --attachable coolify 2>/dev/null
# docker network create --attachable --driver=overlay coolify-overlay 2>/dev/null

if [ -f /var/lib/coolify/source/docker-compose.custom.yml ]; then
    echo "docker-compose.custom.yml detected." >> $LOGFILE
    docker run -v /var/lib/coolify/source:/var/lib/coolify/source -v /var/run/docker.sock:/var/run/docker.sock --rm ghcr.io/coollabsio/coolify-helper:${LATEST_HELPER_VERSION} bash -c "LATEST_IMAGE=${LATEST_IMAGE} docker compose --env-file /var/lib/coolify/source/.env -f /var/lib/coolify/source/docker-compose.yml -f /var/lib/coolify/source/docker-compose.prod.yml -f /var/lib/coolify/source/docker-compose.custom.yml up -d --remove-orphans --force-recreate --wait --wait-timeout 60" >> $LOGFILE 2>&1
else
    docker run -v /var/lib/coolify/source:/var/lib/coolify/source -v /var/run/docker.sock:/var/run/docker.sock --rm ghcr.io/coollabsio/coolify-helper:${LATEST_HELPER_VERSION} bash -c "LATEST_IMAGE=${LATEST_IMAGE} docker compose --env-file /var/lib/coolify/source/.env -f /var/lib/coolify/source/docker-compose.yml -f /var/lib/coolify/source/docker-compose.prod.yml up -d --remove-orphans --force-recreate --wait --wait-timeout 60" >> $LOGFILE 2>&1
fi
