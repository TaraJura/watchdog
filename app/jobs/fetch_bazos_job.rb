class FetchBazosJob < ApplicationJob
  queue_as :default

  # Price ranges to fetch
  PRICE_RANGES = [
    { from: 10000, to: 50000, chat_id: '@bazosfirstfetch' },
    { from: 50000, to: 100000, chat_id: '@bazossecondfetch' },
    { from: 100000, to: 300000, chat_id: '@bazosthirdfetch' }
  ].freeze

  def perform(price_range_index = 0)
    range = PRICE_RANGES[price_range_index]

    Rails.logger.info "[FetchBazosJob] Fetching Bazos ads: #{range[:from]} - #{range[:to]} CZK"

    fetch_and_notify(range)

    # Schedule next price range or restart from beginning
    next_index = (price_range_index + 1) % PRICE_RANGES.size
    wait_time = next_index == 0 ? 60.seconds : 10.seconds # Wait longer after completing all ranges

    FetchBazosJob.set(wait: wait_time).perform_later(next_index)
  rescue StandardError => e
    Rails.logger.error "[FetchBazosJob] Error: #{e.message}"
    # Retry after error
    FetchBazosJob.set(wait: 30.seconds).perform_later(price_range_index)
  end

  private

  def fetch_and_notify(range)
    new_cars = fetch_bazos_ads(range[:from], range[:to], range[:chat_id])

    if new_cars.any?
      Rails.logger.info "[FetchBazosJob] Found #{new_cars.size} new cars"
      broadcast_new_cars(new_cars, 'bazos')
    end
  end

  def fetch_bazos_ads(price_from, price_to, chat_id)
    require 'net/http'
    require 'json'

    new_cars = []
    offset = 0
    max_offset = 400 # Limit to avoid too many requests

    while offset <= max_offset
      params = {
        category: 'osobni',
        limit: 200,
        offset: offset,
        price_from: price_from,
        price_to: price_to
      }

      url = URI.parse("https://www.bazos.cz/api/v1/ads.php?#{URI.encode_www_form(params)}")

      response = Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
        http.request(Net::HTTP::Get.new(url.request_uri))
      end

      break unless response.is_a?(Net::HTTPSuccess)

      ads = JSON.parse(response.body) rescue []
      break if ads.empty?

      # Filter out dealers (premise) and non-car URLs
      ads = ads.reject { |ad| ad.key?("premise") }
      # ONLY accept URLs from auto.bazos.cz (cars only!)
      ads = ads.select { |ad| ad['url'].to_s.include?('auto.bazos.cz') }

      current_urls = ads.map { |ad| ad['url'] }
      existing_urls = Car.where(url: current_urls).pluck(:url).to_set

      new_ads = ads.reject { |ad| existing_urls.include?(ad['url']) }

      if new_ads.any?
        cars_attributes = new_ads.map do |ad|
          {
            api_id: ad['id'],
            title: ad['title'],
            listed_at: Time.parse(ad['from']),
            price_formatted: ad['price_formatted'],
            currency: ad['currency'],
            image_thumbnail: ad['image_thumbnail'],
            locality: ad['locality'],
            topped: ad['topped'] == 'true',
            image_width: ad['image_thumbnail_width'].to_i,
            image_height: ad['image_thumbnail_height'].to_i,
            favourite: ad['favourite'] == 'true',
            url: ad['url'],
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        Car.insert_all(cars_attributes)
        new_cars.concat(cars_attributes)

        # Send Telegram notifications
        new_ads.each do |ad|
          text = "[#{ad['title']}](#{ad['url']})"
          SendTelegramMessageJob.perform_later(text, chat_id)
        end
      end

      offset += 200
      sleep 0.5
    end

    new_cars
  end

  def broadcast_new_cars(cars, source)
    cars.each do |car|
      ActionCable.server.broadcast('notifications_channel', {
        type: 'new_car',
        source: source,
        car: {
          title: car[:title],
          price: car[:price_formatted],
          url: car[:url],
          image: car[:image_thumbnail],
          locality: car[:locality]
        }
      })
    end
  end
end
