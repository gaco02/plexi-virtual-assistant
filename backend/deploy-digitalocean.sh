#!/usr/bin/env bash
# deploy-digitalocean.sh — Set up and deploy Plexi on a Digital Ocean Droplet
# Usage:
#   1. Create an Ubuntu 24.04 Droplet on Digital Ocean
#   2. SSH into the Droplet: ssh root@<DROPLET_IP>
#   3. Clone the repo:  git clone <repo-url> /opt/plexi
#   4. Copy your env:   cp /opt/plexi/backend/.env.production.example /opt/plexi/backend/.env
#      Then edit /opt/plexi/backend/.env with your actual secrets
#   5. Run this script: cd /opt/plexi/backend && ./deploy-digitalocean.sh

set -euo pipefail

APP_DIR="/opt/plexi/backend"

echo "==> [1/5] Installing Docker (if not already installed)..."
if ! command -v docker &> /dev/null; then
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker
    echo "    Docker installed."
else
    echo "    Docker already installed, skipping."
fi

echo "==> [2/5] Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 22/tcp    # SSH
    ufw allow 8080/tcp  # API
    ufw --force enable
    echo "    Firewall configured: SSH (22) + API (8080) open."
else
    echo "    ufw not found, skipping firewall configuration."
fi

echo "==> [3/5] Checking .env file..."
if [ ! -f "${APP_DIR}/.env" ]; then
    echo "    ERROR: ${APP_DIR}/.env not found."
    echo "    Copy the example and fill in your secrets:"
    echo "      cp ${APP_DIR}/.env.production.example ${APP_DIR}/.env"
    echo "      nano ${APP_DIR}/.env"
    exit 1
fi
echo "    .env file found."

echo "==> [4/5] Building and starting services..."
cd "${APP_DIR}"
docker compose down --remove-orphans 2>/dev/null || true
docker compose up -d --build
echo "    Services started."

echo "==> [5/5] Waiting for health check..."
sleep 10
if curl -sf http://localhost:8080/health > /dev/null; then
    echo "    Health check passed!"
    curl -s http://localhost:8080/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8080/health
else
    echo "    WARNING: Health check failed. Check logs with: docker compose logs api"
fi

echo ""
echo "==> Deployment complete!"
echo "    API running at: http://$(curl -s ifconfig.me 2>/dev/null || echo '<DROPLET_IP>'):8080"
echo ""
echo "    Useful commands:"
echo "      docker compose logs -f api       # Follow API logs"
echo "      docker compose logs -f postgres  # Follow DB logs"
echo "      docker compose ps                # Check service status"
echo "      docker compose down              # Stop all services"
echo "      docker compose up -d --build     # Rebuild and restart"
