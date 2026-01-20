# CLAUDE.md - Watchdog Project

## Overview

**Watchdog** is a Rails application that monitors Czech automotive websites (Bazos.cz and Sauto.cz) for car advertisements, stores them in a database, and provides real-time notifications via WebSocket.

**Repository:** https://github.com/TaraJura/watchdog.git

## Technology Stack

| Component | Version/Details |
|-----------|-----------------|
| Ruby | 4.0.1 |
| Rails | 8.0.4 |
| Database | SQLite3 |
| Web Server | Puma |
| Background Jobs | Sidekiq |
| Real-time | ActionCable (WebSocket) |
| HTTP Client | HTTParty, Net::HTTP |
| HTML Parsing | Nokogiri |

## Project Structure

```
watchdog/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   └── cars_controller.rb        # Main UI and API endpoints
│   ├── jobs/
│   │   ├── application_job.rb
│   │   ├── fetch_bazos_job.rb        # Bazos.cz HTML scraper
│   │   └── fetch_sauto_job.rb        # Sauto.cz API fetcher
│   ├── models/
│   │   └── car.rb                    # Car model with scopes
│   ├── channels/
│   │   └── notifications_channel.rb  # WebSocket notifications
│   └── views/cars/
│       └── index.html.erb            # Dashboard UI
├── config/
│   ├── routes.rb                     # Route definitions
│   ├── sidekiq.yml                   # Sidekiq configuration
│   ├── database.yml                  # SQLite3 config
│   ├── puma.rb                       # Puma server config
│   └── initializers/
│       └── start_fetch_jobs.rb       # Auto-start jobs
├── db/
│   ├── migrate/                      # Database migrations
│   └── schema.rb                     # Current schema
├── storage/                          # SQLite database files
├── Dockerfile                        # Production Docker build
└── Gemfile                           # Ruby dependencies
```

## Database Schema

### Table: `cars`

| Column | Type | Description |
|--------|------|-------------|
| id | integer | Primary key |
| title | string | Car listing title (required) |
| url | string | Link to listing (unique, required) |
| source | string | Source portal: 'bazos' or 'sauto' (indexed) |
| price_formatted | string | Display price (e.g., "150 000 Kc") |
| price_cents | integer | Price in cents for filtering (indexed) |
| image_thumbnail | string | Thumbnail URL |
| locality | string | Car location |
| created_at | datetime | Record creation time |
| updated_at | datetime | Last update time |

## Core Components

### 1. Fetch Jobs

**FetchBazosJob** (`app/jobs/fetch_bazos_job.rb`)
- Scrapes Bazos.cz HTML pages using Nokogiri
- Polls every 5 seconds
- Deduplicates by URL
- Broadcasts new cars via ActionCable

**FetchSautoJob** (`app/jobs/fetch_sauto_job.rb`)
- Fetches from Sauto.cz JSON API
- Polls every 5 seconds
- Deduplicates by URL
- Broadcasts new cars via ActionCable

### 2. Car Model (`app/models/car.rb`)

Key scopes:
- `Car.bazos` / `Car.sauto` - Filter by source
- `Car.by_source(source)` - Dynamic source filter
- `Car.min_price(cents)` / `Car.max_price(cents)` - Price filtering
- `Car.search(query)` - Title search
- `Car.today` - Today's listings
- `Car.recent` - Ordered by newest
- `Car.stats` - Dashboard statistics

### 3. CarsController

| Action | Path | Description |
|--------|------|-------------|
| index | `/` | Dashboard with filtering |
| start_fetching | `POST /start_fetching` | Start fetch jobs |
| stats | `/stats` | JSON statistics |

### 4. Real-time Notifications

WebSocket channel broadcasts new cars as they're found:
```javascript
// Subscribe to notifications_channel
// Receive: { type: 'new_car', source: 'bazos'|'sauto', car: {...} }
```

## Routes

| Path | Method | Description |
|------|--------|-------------|
| `/` | GET | Dashboard |
| `/start_fetching` | POST | Start fetch jobs |
| `/stats` | GET | JSON statistics |
| `/up` | GET | Health check |
| `/sidekiq` | GET | Sidekiq Web UI |
| `/cable` | WS | ActionCable WebSocket |

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
| AUTO_START_FETCH | false | Auto-start fetch jobs in dev |
| REDIS_URL | redis://localhost:6379/1 | Redis for ActionCable |
| RAILS_MASTER_KEY | - | Encrypted credentials key |

### Auto-start Jobs

Jobs auto-start in production. For development, set:
```bash
AUTO_START_FETCH=true rails server
```

Or use the "Start Fetching" button in the UI.

## Key Files Reference

| File | Purpose |
|------|---------|
| `app/jobs/fetch_bazos_job.rb` | Bazos.cz scraper job |
| `app/jobs/fetch_sauto_job.rb` | Sauto.cz API fetcher job |
| `app/models/car.rb` | Car model with scopes and validations |
| `app/controllers/cars_controller.rb` | Main controller |
| `app/channels/notifications_channel.rb` | WebSocket channel |
| `config/initializers/start_fetch_jobs.rb` | Auto-start configuration |
| `db/schema.rb` | Database schema |

## Testing

```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/car_test.rb
```

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

### Database Migration

```bash
# Production migration
cd /home/novakj/watchdog
SECRET_KEY_BASE=<key> RAILS_ENV=production bundle exec rails db:migrate
```

## Architecture Notes

- **Single Fetching System**: Jobs in `app/jobs/` handle all fetching
- **URL-based Deduplication**: Both sources use URL for uniqueness
- **Efficient Price Filtering**: `price_cents` column enables fast queries
- **Source Column**: Direct filtering without URL pattern matching
- **WebSocket Notifications**: Real-time updates via ActionCable
- **Auto-reschedule**: Jobs reschedule themselves every 5 seconds
- **Error Recovery**: Jobs continue running even after errors
