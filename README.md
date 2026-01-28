# Watchdog

A Rails application that monitors Czech automotive websites (Bazos.cz and Sauto.cz) for car advertisements, stores them in a database, and sends real-time notifications via Push Notifications, Telegram, and WebSocket.

## Features

- **Real-time Monitoring** - Continuously scrapes Bazos.cz and Sauto.cz for new car listings
- **Push Notifications** - Browser push notifications for new car listings
- **Telegram Notifications** - Instant alerts sent to configured Telegram channels
- **Live Web UI** - Dark-themed dashboard with WebSocket-powered real-time updates
- **Filtering & Search** - Filter by price range, source, and search by title
- **Background Processing** - Sidekiq-powered job queue for reliable fetching

## Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Ruby on Rails 8.0.4 |
| Ruby | 4.0.1 |
| Database | SQLite3 |
| Background Jobs | Sidekiq |
| Real-time | ActionCable (WebSocket) |
| HTTP Client | HTTParty, Net::HTTP |
| HTML Parsing | Nokogiri |
| Notifications | Telegram Bot API |

## Quick Start

### Prerequisites

- Ruby 4.0.1
- Bundler
- Redis (for Sidekiq)
- Node.js (for push notifications)

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

### Push Notifications Setup

Browser push notifications require VAPID keys for authentication.

#### Generate VAPID Keys

```bash
npx web-push generate-vapid-keys
```

This will output:
```
Public Key: BKI...
Private Key: I7u...
```

#### Configure Environment Variables

Create a `.env` file in the project root:

```bash
VAPID_PUBLIC_KEY=your_public_key_here
VAPID_PRIVATE_KEY=your_private_key_here
```

**Important**: The `.env` file is gitignored and should never be committed to version control.

#### HTTPS Requirement

Push notifications only work over HTTPS (or localhost). For production deployment, ensure your application is served over HTTPS.

For local testing on mobile devices, use a tunnel service:

```bash
# Using ngrok
ngrok http 3000

# Using localtunnel
npx localtunnel --port 3000
```

#### How It Works

- Users are automatically subscribed to push notifications when they visit the dashboard
- New car listings trigger instant browser notifications
- Notifications include car title, price, thumbnail, and clickable link to the listing
- Works even when the browser tab is closed (requires Service Worker support)

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RAILS_ENV` | development | Rails environment |
| `PORT` | 3000 | Server port |
| `WEB_CONCURRENCY` | 1 | Puma workers |
| `RAILS_MAX_THREADS` | 5 | Thread pool size |
| `SECRET_KEY_BASE` | - | Required in production |
| `VAPID_PUBLIC_KEY` | - | Public key for push notifications |
| `VAPID_PRIVATE_KEY` | - | Private key for push notifications |

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

### Push Notifications in Production

Ensure VAPID keys are set in your production environment:

```bash
# Set environment variables on your server
export VAPID_PUBLIC_KEY=your_public_key
export VAPID_PRIVATE_KEY=your_private_key

# Or add to systemd service file
Environment="VAPID_PUBLIC_KEY=your_public_key"
Environment="VAPID_PRIVATE_KEY=your_private_key"
```

The application must be served over HTTPS for push notifications to work in production.

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
