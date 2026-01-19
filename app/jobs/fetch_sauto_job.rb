class FetchSautoJob < ApplicationJob
  queue_as :default

  POLL_INTERVAL = 5.seconds
  FETCH_LIMIT = 30

  def perform
    new_cars = fetch_newest_ads

    if new_cars.any?
      Rails.logger.info "[FetchSautoJob] Found #{new_cars.size} new cars!"
      broadcast_new_cars(new_cars)
    end

    FetchSautoJob.set(wait: POLL_INTERVAL).perform_later
  rescue StandardError => e
    Rails.logger.error "[FetchSautoJob] Error: #{e.message}"
    FetchSautoJob.set(wait: POLL_INTERVAL).perform_later
  end

  private

  def fetch_newest_ads
    require 'net/http'
    require 'json'

    url = URI("https://www.sauto.cz/api/v1/items/search?category_id=838&limit=#{FETCH_LIMIT}&offset=0&prodejce=soukromy")

    response = Net::HTTP.start(url.host, url.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.request(Net::HTTP::Get.new(url.request_uri))
    end

    return [] unless response.is_a?(Net::HTTPSuccess)

    results = JSON.parse(response.body)['results'] rescue []
    return [] if results.nil? || results.empty?

    # Check which are new
    titles = results.map { |ad| ad['name'] }
    existing = Car.where(title: titles).pluck(:title).to_set

    new_ads = results.reject { |ad| existing.include?(ad['name']) }
    return [] if new_ads.empty?

    # Save new cars
    cars_attributes = new_ads.filter_map do |ad|
      ad_id = ad['id']
      next unless ad_id

      category = ad['category'].is_a?(Hash) ? ad['category']['seo_name'] : nil
      brand = ad['manufacturer_cb'].is_a?(Hash) ? ad['manufacturer_cb']['seo_name'] : nil
      model = ad['model_cb'].is_a?(Hash) ? ad['model_cb']['seo_name'] : nil

      car_url = if category && brand && model
        "https://www.sauto.cz/#{category}/detail/#{brand}/#{model}/#{ad_id}"
      else
        "https://www.sauto.cz/detail/#{ad_id}"
      end

      price = ad['price'].is_a?(Hash) ? ad['price']['value'] : nil
      price_formatted = price ? "#{price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse} Kč" : nil

      photos = ad['photos']
      image = photos.is_a?(Array) && photos.first.is_a?(Hash) ? photos.first['url'] : nil

      locality = ad['locality'].is_a?(Hash) ? ad['locality']['name'] : nil

      {
        title: ad['name'],
        url: car_url,
        price_formatted: price_formatted,
        image_thumbnail: image,
        locality: locality,
        api_id: ad_id.to_s,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    return [] if cars_attributes.empty?

    Car.insert_all(cars_attributes)
    cars_attributes
  end

  def broadcast_new_cars(cars)
    cars.each do |car|
      ActionCable.server.broadcast('notifications_channel', {
        type: 'new_car',
        source: 'sauto',
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
