# Watchdog

A Rails application that monitors Czech automotive websites (Bazos.cz and Sauto.cz) for car advertisements, stores them in a database, and sends real-time notifications via Telegram and WebSocket.

## Features

- **Real-time Monitoring** - Continuously scrapes Bazos.cz and Sauto.cz for new car listings
- **Telegram Notifications** - Instant alerts sent to configured Telegram channels
- **Live Web UI** - Dark-themed dashboard with WebSocket-powered real-time updates
- **Filtering & Search** - Filter by price range, source, and search by title
- **Background Processing** - Sidekiq-powered job queue for reliable fetching

## Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Ruby on Rails 7.1 |
| Ruby | 3.4.1 |
| Database | SQLite3 |
| Background Jobs | Sidekiq |
| Real-time | ActionCable (WebSocket) |
| HTTP Client | HTTParty, Net::HTTP |
| HTML Parsing | Nokogiri |
| Notifications | Telegram Bot API |

## Quick Start

### Prerequisites

- Ruby 3.4.1
- Bundler
- Redis (for Sidekiq)

### Installation

```bash
# Clone the repository
git clone https://github.com/TaraJura/watchdog.git
cd watchdog

# Install dependencies
bundle install

# Setup database
rails db:create db:migrate

# Start the server
rails server
```

### Running Background Jobs

In a separate terminal:

```bash
bundle exec sidekiq
```

### Running the Fetchers

```bash
# Run multithreaded parallel fetch (Bazos + Sauto)
rake bazos:fetch_parallel
```

Or trigger via the web UI by clicking "Start Fetching" on the dashboard.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RAILS_ENV` | development | Rails environment |
| `PORT` | 3000 | Server port |
| `WEB_CONCURRENCY` | 1 | Puma workers |
| `RAILS_MAX_THREADS` | 5 | Thread pool size |
| `SECRET_KEY_BASE` | - | Required in production |

### Telegram Channels

The app sends notifications to these Telegram channels based on price range:

| Channel | Price Range (CZK) |
|---------|-------------------|
| @bazosfirstfetch | 10,000 - 50,000 |
| @bazossecondfetch | 50,000 - 100,000 |
| @bazosthirdfetch | 100,000 - 300,000 |
| @sautobot1 | Sauto listings |

## Web Interface

Access the dashboard at `http://localhost:3000`

- **Tabs** - Switch between Bazos, Sauto, or All listings
- **Filters** - Set min/max price, search by title
- **Live Updates** - New cars appear automatically via WebSocket
- **Statistics** - View total and daily counts per source

### Endpoints

| Path | Description |
|------|-------------|
| `/` | Main dashboard |
| `/up` | Health check |
| `/stats` | JSON statistics API |
| `/sidekiq` | Sidekiq Web UI |

## Docker

```bash
# Build image
docker build -t watchdog .

# Run container
docker run -p 3000:3000 watchdog
```

## Project Structure

```
watchdog/
├── app/
│   ├── controllers/
│   │   ├── cars_controller.rb        # Main UI & API
│   │   └── watchdog_controller.rb    # Health check
│   ├── jobs/
│   │   ├── fetch_bazos_job.rb        # Bazos scraper
│   │   ├── fetch_sauto_job.rb        # Sauto fetcher
│   │   └── send_telegram_message_job.rb
│   ├── channels/
│   │   └── notifications_channel.rb  # WebSocket
│   └── views/cars/
│       └── index.html.erb            # Dashboard UI
├── lib/
│   ├── bazos.rb                      # Legacy Bazos fetcher
│   ├── sauto.rb                      # Legacy Sauto fetcher
│   ├── telegram_bot.rb               # Telegram integration
│   └── tasks/
│       └── bazos.rake                # Parallel fetch task
├── config/
│   ├── routes.rb
│   ├── sidekiq.yml
│   └── puma.rb
└── db/
    └── schema.rb
```

## Database Schema

### Cars Table

| Column | Type | Description |
|--------|------|-------------|
| title | string | Car listing title |
| url | string | Link to listing (unique) |
| api_id | string | Source API ID |
| price_formatted | string | Display price |
| locality | string | Car location |
| image_thumbnail | string | Thumbnail URL |
| listed_at | datetime | Listing date |

## Production Deployment

### Services

```bash
# Check service status
sudo systemctl status watchdog.service
sudo systemctl status watchdog-sidekiq.service

# Restart services
sudo systemctl restart watchdog.service
sudo systemctl restart watchdog-sidekiq.service

# View logs
sudo journalctl -u watchdog.service -f
```

### Running in Production

```bash
RAILS_ENV=production rails db:migrate
RAILS_ENV=production rails server
```

## Testing

```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/car_test.rb
```

## License

This project is for personal/internal use.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
