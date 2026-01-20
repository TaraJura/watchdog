#!/bin/bash
set -e

# Watchdog Deploy Script
# Usage: ./deploy.sh

APP_DIR="/home/novakj/watchdog"
SERVICE_NAME="watchdog"
SIDEKIQ_SERVICE="watchdog-sidekiq"

cd "$APP_DIR"

echo "=== Watchdog Deployment ==="
echo ""

# 1. Git pull
echo "[1/5] Pulling latest changes..."
git pull

# 2. Bundle install (in case Gemfile changed)
echo ""
echo "[2/5] Installing dependencies..."
bundle install --quiet

# 3. Backup database before migrations
echo ""
echo "[3/5] Backing up database..."
BACKUP_FILE="storage/production.sqlite3.bak.$(date +%Y%m%d_%H%M%S)"
cp storage/production.sqlite3 "$BACKUP_FILE"
echo "      Backup: $BACKUP_FILE"

# 4. Run migrations
echo ""
echo "[4/5] Running database migrations..."
RAILS_ENV=production bundle exec rails db:migrate

# 5. Restart services
echo ""
echo "[5/5] Restarting services..."
sudo systemctl restart "$SERVICE_NAME"
sudo systemctl restart "$SIDEKIQ_SERVICE"

# Verify
echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Service status:"
sudo systemctl is-active "$SERVICE_NAME" && echo "  $SERVICE_NAME: running" || echo "  $SERVICE_NAME: FAILED"
sudo systemctl is-active "$SIDEKIQ_SERVICE" && echo "  $SIDEKIQ_SERVICE: running" || echo "  $SIDEKIQ_SERVICE: FAILED"
echo ""
echo "Testing endpoint..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3003/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "  Homepage: OK (HTTP $HTTP_CODE)"
else
    echo "  Homepage: FAILED (HTTP $HTTP_CODE)"
    echo "  Check logs: sudo journalctl -u $SERVICE_NAME -n 50"
fi
