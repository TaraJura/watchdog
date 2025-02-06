require 'net/http'
require 'uri'
require 'json'

class Bazos
  API_URL = 'https://www.bazos.cz/api/v1/ads.php'.freeze
  MAX_LIMIT = 200
  MAX_OFFSET = 2000

  def self.fetch_ads
    offset = 0

    while offset <= MAX_OFFSET
      url = build_url(offset)
      response = make_request(url)

      break unless response.is_a?(Net::HTTPSuccess)

      ads = parse_response(response.body)
      break if ads.empty?

      save_ads(ads)
      offset = 0 if offset == MAX_OFFSET
      offset += MAX_LIMIT
    end
  end

  private

  def self.build_url(offset)
    params = {
      section: 'auto',
      limit: MAX_LIMIT,
      offset: offset,
      price_from: 5000,
      price_to: 50000
    }

    URI.parse(API_URL + "?#{URI.encode_www_form(params)}")
  end

  def self.make_request(url)
    Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
      http.request(Net::HTTP::Get.new(url.request_uri))
    end
  end

  def self.parse_response(body)
    JSON.parse(body) rescue []
  end

  def self.save_ads(ads)
    current_urls = ads.map { |ad| ad['url'] }
    existing_urls = Car.where(url: current_urls).pluck(:url).to_set

    new_ads = ads.reject { |ad| existing_urls.include?(ad['url']) }
    return if new_ads.empty?

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
        url: ad['url']
      }
    end

    # Bulk insert new records
    Car.insert_all(cars_attributes)

    # Enqueue jobs for new ads
    new_ads.each do |ad|
      puts "Enqueueing job for #{ad['url']}"
      SendTelegramMessageJob.perform_later(ad['url'])
    end
  end
end
