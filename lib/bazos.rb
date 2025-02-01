require 'net/http'
require 'uri'
require 'nokogiri'
require 'digest'
require 'logger'

class Bazos
  # Configure logging
  @@logger = Logger.new('bazos_scraper.log')

  # Constants for configuration
  BATCH_SIZE = 20
  MAX_OFFSET = 1500
  BASE_URL = 'https://auto.bazos.cz'

  class ScrapingError < StandardError; end

  def self.fetch_content(options = {})
    @@logger.info "Starting scraping process"
    offset = options.fetch(:starting_offset, 0)

    loop do
      begin
        url = build_url(offset)
        @@logger.debug "Fetching URL: #{url}"

        response = fetch_page(url)

        unless response.is_a?(Net::HTTPSuccess)
          @@logger.error "Failed to fetch page: #{response.code} - #{response.message}"
          break
        end

        cars_count = parse_and_save_cars(response.body)
        @@logger.info "Processed #{cars_count} cars at offset #{offset}"

        # Reset offset if we've reached the maximum
        if offset >= MAX_OFFSET
          @@logger.info "Reached maximum offset, resetting to 0"
          offset = 0
        else
          offset += BATCH_SIZE
        end

        # Optional delay to be nice to the server
        sleep(options.fetch(:delay, 1))
      rescue StandardError => e
        @@logger.error "Error during scraping: #{e.message}\n#{e.backtrace.join("\n")}"
        raise ScrapingError, "Failed to scrape page at offset #{offset}: #{e.message}"
      end
    end

    @@logger.info "Scraping process completed"
  end

  private

  def self.build_url(offset)
    base_params = {
      hledat: 'auto',
      hlokalita: '',
      humkreis: 25,
      cenaod: 50000,
      cenado: 100000,
      order: ''
    }

    path = offset.positive? ? "/#{offset}/" : "/"
    URI::HTTPS.build(
      host: BASE_URL.gsub('https://', ''),
      path: path,
      query: URI.encode_www_form(base_params)
    )
  end

  def self.fetch_page(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.read_timeout = 10
    http.open_timeout = 10

    request = Net::HTTP::Get.new(url.request_uri)
    request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'

    http.request(request)
  end

  def self.parse_and_save_cars(html)
    doc = Nokogiri::HTML(html)
    listings = doc.css('.inzeraty.inzeratyflex')
    cars_processed = 0

    listings.each do |listing|
      begin
        title = listing.css('h2.nadpis a').text.strip
        link = listing.css('h2.nadpis a').attr('href')&.value

        next if title.empty? || link.nil?

        full_link = URI.join(BASE_URL, link).to_s

        # Extract additional details if available
        price = listing.css('.cena').text.strip
        location = listing.css('.inzeratylok').text.strip

        car_found = Car.find_by(title: title, link: full_link)

        unless car_found.present?
          Car.create!(
            title: title,
            link: full_link,
            price: price,
            location: location
          )

          notify_new_car(title, full_link, price, location)
          cars_processed += 1
        end
      rescue StandardError => e
        @@logger.error "Error processing listing: #{e.message}"
        next
      end
    end

    cars_processed
  end

  def self.notify_new_car(title, link, price, location)
    message = <<~MSG
      🚗 Nové auto:
      #{title}
      💰 #{price}
      📍 #{location}
      🔗 [Zobrazit detail](#{link})
    MSG

    TelegramBot.send_message(
      message,
      parse_mode: 'Markdown'
    )
  rescue StandardError => e
    @@logger.error "Failed to send Telegram notification: #{e.message}"
  end
end
