class FetchSautoJob < ApplicationJob
  queue_as :default

  CHAT_ID = '@sautobot1'.freeze

  def perform
    Rails.logger.info "[FetchSautoJob] Fetching Sauto ads..."

    new_cars = fetch_sauto_ads

    if new_cars.any?
      Rails.logger.info "[FetchSautoJob] Found #{new_cars.size} new cars"
      broadcast_new_cars(new_cars, 'sauto')
    end

    # Reschedule to run again in 30 seconds
    FetchSautoJob.set(wait: 30.seconds).perform_later
  rescue StandardError => e
    Rails.logger.error "[FetchSautoJob] Error: #{e.message}"
    # Retry after error
    FetchSautoJob.set(wait: 30.seconds).perform_later
  end

  private

  def fetch_sauto_ads
    require 'net/http'
    require 'json'

    new_cars = []

    url = URI("https://www.sauto.cz/api/v1/items/search?category_id=838&limit=50&offset=0&prodejce=soukromy")
    response = Net::HTTP.get_response(url)

    return new_cars unless response.is_a?(Net::HTTPSuccess)

    results = JSON.parse(response.body)['results'] rescue []
    return new_cars if results.nil? || results.empty?

    results.each do |ad|
      next if Car.exists?(title: ad['name'])

      ad_id = ad["id"]
      category = ad.dig('category', 'seo_name')
      brand = ad.dig('manufacturer_cb', 'seo_name')
      model = ad.dig('model_cb', 'seo_name')
      url = "https://www.sauto.cz/#{category}/detail/#{brand}/#{model}/#{ad_id}"

      price = ad.dig('price', 'value')
      price_formatted = price ? "#{price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse} Kč" : nil

      image = ad.dig('photos', 0, 'url')
      locality = ad.dig('locality', 'name')

      car = Car.create!(
        title: ad['name'],
        url: url,
        price_formatted: price_formatted,
        image_thumbnail: image,
        locality: locality,
        api_id: ad_id.to_s
      )

      new_cars << {
        title: car.title,
        price_formatted: car.price_formatted,
        url: car.url,
        image_thumbnail: car.image_thumbnail,
        locality: car.locality
      }

      # Send Telegram notification
      text = "[#{ad['name']}](#{url})"
      SendTelegramMessageJob.perform_later(text, CHAT_ID)
    end

    new_cars
  rescue StandardError => e
    Rails.logger.error "[FetchSautoJob] Fetch error: #{e.message}"
    []
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
