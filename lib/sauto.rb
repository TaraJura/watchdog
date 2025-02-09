require 'net/http'
require 'uri'
require 'json'

class Sauto
  def self.start
    puts 'Starting Sauto fetcher...'

    loop do
      all_ads = fetch_ads

      all_ads.each do |ad|
        next if Car.exists?(title: ad['name'])

        ad_id = ad["id"]
        category = ad.dig('category', 'seo_name')
        brand = ad.dig('manufacturer_cb', 'seo_name')
        model = ad.dig('model_cb', 'seo_name')
        url = "https://www.sauto.cz/#{category}/detail/#{brand}/#{model}/#{ad_id}"
        text = "[#{ad['name']}](#{url})"

        Car.create(title: ad['name'], url:)
        SendTelegramMessageJob.perform_later(text, '@sautobot1')
      rescue StandardError => e
        puts "Error fetching ads: #{e.message}"
      end

      sleep 10
    end
  end

  def self.fetch_ads
    response = Net::HTTP.get_response(URI("https://www.sauto.cz/api/v1/items/search?category_id=838&limit=50&offset=0"))
    return [] unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)['results']
  rescue StandardError => e
    puts "Error fetching ads: #{e.message}"
  end
end
