# CLAUDE.md - Watchdog Project

## Overview

**Watchdog** is a Rails-based application that monitors Czech automotive websites (Bazos.cz and Sauto.cz) for car advertisements, stores them in a database, and sends real-time notifications via Telegram.

**Repository:** https://github.com/TaraJura/watchdog.git

## Technology Stack

| Component | Version/Details |
|-----------|-----------------|
| Ruby | 4.0.1 |
| Rails | 8.0.4 |
| Database | SQLite3 |
| Web Server | Puma |
| Background Jobs | Sidekiq |
| HTTP Client | HTTParty |
| Notifications | Telegram Bot API |

## Project Structure

```
watchdog/
├── app/
│   ├── controllers/
│   │   └── watchdog_controller.rb    # Health check endpoint
│   ├── jobs/
│   │   └── send_telegram_message_job.rb  # Async Telegram notifications
│   ├── models/
│   │   └── car.rb                    # Car advertisement model
│   └── views/layouts/
├── config/
│   ├── routes.rb                     # Route definitions
│   ├── sidekiq.yml                   # Sidekiq configuration
│   ├── database.yml                  # SQLite3 config
│   └── puma.rb                       # Puma server config
├── db/
│   ├── migrate/                      # Database migrations
│   └── schema.rb                     # Current schema
├── lib/
│   ├── bazos.rb                      # Bazos.cz API fetcher
│   ├── sauto.rb                      # Sauto.cz fetcher (continuous loop)
│   ├── telegram_bot.rb               # Telegram notification service
│   └── tasks/
│       └── bazos.rake                # Multithreaded fetch task
├── storage/                          # SQLite database files
├── Dockerfile                        # Production Docker build
└── Gemfile                           # Ruby dependencies
```

## Database Schema

### Table: `cars`

| Column | Type | Description |
|--------|------|-------------|
| id | integer | Primary key |
| title | string | Car listing title |
| url | string | Link to listing (unique index) |
| api_id | string | Source API ID (unique index) |
| listed_at | datetime | When car was listed |
| price_formatted | string | Display price (e.g., "150,000 Kc") |
| currency | string | Currency code |
| image_thumbnail | string | Thumbnail URL |
| locality | string | Car location |
| topped | boolean | Featured listing flag |
| favourite | boolean | Marked as favourite |
| created_at | datetime | Record creation time |
| updated_at | datetime | Last update time |

## Core Components

### 1. Ad Fetchers

**Bazos Fetcher** (`lib/bazos.rb`)
- Fetches from Bazos.cz API with price range filters
- Paginated requests (limit 200, max offset 2000)
- Filters out ads with "premise" field (dealers)
- Bulk inserts new records
- Enqueues Telegram notifications for new finds

**Sauto Fetcher** (`lib/sauto.rb`)
- Continuous loop fetcher for Sauto.cz
- 10-second sleep between fetches
- Checks duplicates by title
- Sends to `@sautobot1` Telegram channel

### 2. Telegram Bot (`lib/telegram_bot.rb`)
- Sends formatted messages via Telegram Bot API
- Uses Markdown parsing
- **WARNING:** Token is hardcoded - should be moved to ENV

### 3. Background Jobs
- **SendTelegramMessageJob**: Async Telegram message delivery via Sidekiq

### 4. Telegram Channels

| Channel | Price Range |
|---------|-------------|
| @bazosfirstfetch | 5,000 - 50,000 CZK |
| @bazossecondfetch | 50,000 - 100,000 CZK |
| @bazosthirdfetch | 100,000 - 300,000 CZK |
| @sautobot1 | Sauto listings |

## Routes

| Path | Description |
|------|-------------|
| `/up` | Health check (returns `{ status: 'ok' }`) |
| `/sidekiq` | Sidekiq Web UI |

## Commands

### Development

```bash
# Install dependencies
bundle install

# Setup database
rails db:create db:migrate

# Start Rails server
rails server

# Start Sidekiq (separate terminal)
bundle exec sidekiq

# Rails console
rails console
```

### Production

```bash
# Database operations
RAILS_ENV=production rails db:migrate

# Console
RAILS_ENV=production rails console

# Start server
RAILS_ENV=production rails server
```

### Running Fetchers

```bash
# Run multithreaded parallel fetch (Bazos + Sauto)
rake bazos:fetch_parallel

# This launches:
# - 3 Bazos threads (different price ranges)
# - 1 Sauto continuous thread
```

### Docker

```bash
# Build image
docker build -t watchdog .

# Run container
docker run -p 3000:3000 watchdog
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| RAILS_ENV | development | Rails environment |
| PORT | 3000 | Server port |
| WEB_CONCURRENCY | 1 | Puma workers |
| RAILS_MAX_THREADS | 5 | Thread pool size |
| REDIS_URL | redis://localhost:6379/1 | Redis for Action Cable |
| RAILS_MASTER_KEY | - | Encrypted credentials key |

### Sidekiq (`config/sidekiq.yml`)
- Concurrency: 5 workers
- Queue: `default`

### Puma (`config/puma.rb`)
- Threads: 5 min/max
- Port: 3000
- Workers: 1 (preload app)

## Key Files Reference

| File | Purpose |
|------|---------|
| `lib/bazos.rb` | Main Bazos.cz fetcher with price filters |
| `lib/sauto.rb` | Continuous Sauto.cz fetcher |
| `lib/telegram_bot.rb` | Telegram notification service |
| `lib/tasks/bazos.rake` | Multithreaded parallel fetch task |
| `app/models/car.rb` | Car ActiveRecord model |
| `app/jobs/send_telegram_message_job.rb` | Async Telegram job |
| `db/schema.rb` | Database schema definition |
| `config/sidekiq.yml` | Background job configuration |

## Security Concerns

1. **Hardcoded Telegram Token** in `lib/telegram_bot.rb`
   - Token is visible in source code
   - Should be moved to `Rails.application.credentials` or ENV variable

2. **Silent Error Handling** in `lib/sauto.rb`
   - Errors are rescued but not logged
   - Consider adding proper error logging

## Testing

```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/car_test.rb

# Run system tests
rails test:system
```

Test files location:
- `test/models/car_test.rb`
- `test/controllers/watchdog_controller_test.rb`
- `test/fixtures/cars.yml`

## Troubleshooting

```bash
# Check if Rails server is running
lsof -i :3000

# View Sidekiq processes
ps aux | grep sidekiq

# Check database
sqlite3 storage/development.sqlite3 ".tables"
sqlite3 storage/development.sqlite3 "SELECT COUNT(*) FROM cars;"

# View recent logs
tail -f log/development.log
```

## Deployment

### Services

| Service | Port | Description |
|---------|------|-------------|
| watchdog | 3003 | Rails Puma application |
| watchdog-sidekiq | - | Background job processor |

### Service Commands

```bash
# Check service status
sudo systemctl status watchdog.service
sudo systemctl status watchdog-sidekiq.service

# Restart services
sudo systemctl restart watchdog.service
sudo systemctl restart watchdog-sidekiq.service

# View logs
sudo journalctl -u watchdog.service -f
sudo journalctl -u watchdog-sidekiq.service -f
```

### Nginx

- **Subdomain:** watchdog.techtools.cz
- **Config:** `/etc/nginx/sites-enabled/watchdog.techtools.cz`
- **SSL:** Add via Certbot after DNS A record is configured

```bash
# After adding DNS A record for watchdog.techtools.cz:
sudo certbot --nginx -d watchdog.techtools.cz
```

### Database

```bash
# Production console
cd /home/novakj/watchdog
source ~/.rvm/scripts/rvm && rvm use 3.4.1
SECRET_KEY_BASE=<key> RAILS_ENV=production bundle exec rails console

# Run migrations
SECRET_KEY_BASE=<key> RAILS_ENV=production bundle exec rails db:migrate

# Direct SQLite access
sqlite3 /home/novakj/watchdog/storage/production.sqlite3
```

### Running the Fetcher Task

```bash
# Run via rake (in foreground)
cd /home/novakj/watchdog
source ~/.rvm/scripts/rvm && rvm use 3.4.1
SECRET_KEY_BASE=<key> RAILS_ENV=production bundle exec rake bazos:fetch_parallel
```

## Notes

- App is minimal - primarily a scheduled data fetcher
- Business logic lives in `lib/` rather than controllers
- Designed for single-server SQLite deployment
- No authentication on endpoints (internal use only)
- Telegram integration is the primary output mechanism
