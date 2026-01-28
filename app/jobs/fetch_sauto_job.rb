class FetchSautoJob < ApplicationJob
  queue_as :default

  POLL_INTERVAL = 5.seconds
  FETCH_LIMIT = 30
  API_URL = "https://www.sauto.cz/api/v1/items/search".freeze

  def perform
    new_cars = fetch_newest_ads

    if new_cars.any?
      Rails.logger.info "[FetchSautoJob] Found #{new_cars.size} new cars!"
      broadcast_new_cars(new_cars)
    end

    reschedule
  rescue StandardError => e
    Rails.logger.error "[FetchSautoJob] Error: #{e.message}"
    reschedule
  end

  private

  def reschedule
    FetchSautoJob.set(wait: POLL_INTERVAL).perform_later
  end

  def fetch_newest_ads
    response = fetch_api
    return [] unless response.is_a?(Net::HTTPSuccess)

    results = parse_response(response.body)
    return [] if results.empty?

    save_new_ads(results)
  end

  def fetch_api
    require 'net/http'

    url = URI("#{API_URL}?category_id=838&limit=#{FETCH_LIMIT}&offset=0&prodejce=soukromy")

    Net::HTTP.start(url.host, url.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.request(Net::HTTP::Get.new(url.request_uri))
    end
  end

  def parse_response(body)
    require 'json'

    data = JSON.parse(body)
    results = data['results']
    return [] if results.nil? || results.empty?

    results.filter_map { |ad| parse_ad(ad) }
  rescue JSON::ParserError
    []
  end

  def parse_ad(ad)
    ad_id = ad['id']
    return nil unless ad_id

    title = ad['name']
    return nil if title.blank?

    car_url = build_url(ad, ad_id)
    price_value = extract_price(ad)
    price_formatted = format_price(price_value)

    {
      url: car_url,
      title: title,
      image_thumbnail: extract_image(ad),
      price_formatted: price_formatted,
      price_cents: price_value ? price_value * 100 : nil,
      locality: ad.dig('locality', 'name'),
      source: 'sauto'
    }
  end

  def build_url(ad, ad_id)
    category = ad.dig('category', 'seo_name')
    brand = ad.dig('manufacturer_cb', 'seo_name')
    model = ad.dig('model_cb', 'seo_name')

    if category && brand && model
      "https://www.sauto.cz/#{category}/detail/#{brand}/#{model}/#{ad_id}"
    else
      "https://www.sauto.cz/detail/#{ad_id}"
    end
  end

  def extract_price(ad)
    ad.dig('price', 'value')&.to_i
  end

  def extract_image(ad)
    photos = ad['photos']
    return nil unless photos.is_a?(Array) && photos.first.is_a?(Hash)
    photos.first['url']
  end

  def format_price(price_value)
    return nil unless price_value
    "#{price_value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse} Kč"
  end

  def save_new_ads(ads)
    urls = ads.map { |ad| ad[:url] }
    existing = Car.where(url: urls).pluck(:url).to_set

    new_ads = ads.reject { |ad| existing.include?(ad[:url]) }
    return [] if new_ads.empty?

    cars_attributes = new_ads.map do |ad|
      ad.merge(created_at: Time.current, updated_at: Time.current)
    end

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

      # Send push notification
      PushNotificationService.send_new_car_notification(car)
    end
  end
end
