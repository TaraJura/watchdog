class FetchBazosJob < ApplicationJob
  queue_as :default

  PRICE_FROM = 10_000
  PRICE_TO = 100_000
  POLL_INTERVAL = 5.seconds
  BASE_URL = "https://auto.bazos.cz".freeze

  def perform
    new_cars = fetch_newest_ads

    if new_cars.any?
      Rails.logger.info "[FetchBazosJob] Found #{new_cars.size} new cars!"
      broadcast_new_cars(new_cars)
    end

    reschedule
  rescue StandardError => e
    Rails.logger.error "[FetchBazosJob] Error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    reschedule
  end

  private

  def reschedule
    FetchBazosJob.set(wait: POLL_INTERVAL).perform_later
  end

  def fetch_newest_ads
    response = fetch_page
    return [] unless response.is_a?(Net::HTTPSuccess)

    ads = parse_listings(response.body)
    return [] if ads.empty?

    save_new_ads(ads)
  end

  def fetch_page
    require 'net/http'

    url = URI("#{BASE_URL}/?hledat=&rubriky=auto&cenaod=#{PRICE_FROM}&cenado=#{PRICE_TO}&order=1&kitx=ano")

    Net::HTTP.start(url.host, url.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
      req = Net::HTTP::Get.new(url.request_uri)
      req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      http.request(req)
    end
  end

  def parse_listings(html)
    require 'nokogiri'

    doc = Nokogiri::HTML(html)
    listings = doc.css('div.inzeraty.inzeratyflex')

    listings.filter_map do |listing|
      parse_single_listing(listing)
    end
  end

  def parse_single_listing(listing)
    link = listing.at_css('h2.nadpis a')
    return nil unless link

    title = link.text.strip
    return nil if title.empty?

    url_path = link['href']
    full_url = "#{BASE_URL}#{url_path}"

    price_el = listing.at_css('div.inzeratycena span[translate="no"]')
    price_formatted = price_el&.text&.strip

    {
      url: full_url,
      title: title,
      image_thumbnail: listing.at_css('img.obrazek')&.[]('src'),
      price_formatted: price_formatted,
      price_cents: Car.parse_price_to_cents(price_formatted),
      locality: listing.at_css('div.inzeratylok')&.text&.split("\n")&.first&.strip,
      source: 'bazos'
    }
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
        source: 'bazos',
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
