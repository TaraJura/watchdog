require 'net/http'
require 'uri'
require 'json'

class Sauto
  SAUTO_API_URL = 'https://www.sauto.cz/api/v1/items/search'.freeze

  def self.start
    puts 'Starting Sauto fetcher...'

    all_ads = fetch_ads

    all_ads.each do |ad|
      puts Car.exists?(title: ad['name'])
      next if Car.exists?(title: ad['name'])

      ad_id = ad["id"]
      category = ad.dig('category', 'seo_name')
      brand = ad.dig('manufacturer_cb', 'seo_name')
      model = ad.dig('model_cb', 'seo_name')
      url = "https://www.sauto.cz/#{category}/detail/#{brand}/#{model}/#{ad_id}"
      text = "[#{ad['name']}](#{url})"

      Car.create!(title: ad['name'], url:)
      SendTelegramMessageJob.perform_later(text, '1619339886')
    end
  end

  def fetch_ads
    params = {
      category_id: 838,
      limit: 50,
      offset: 0
    }

    uri = URI(SAUTO_API_URL)
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)
    return [] unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)['results'] rescue []
  end
end
