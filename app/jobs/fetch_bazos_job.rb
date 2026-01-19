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

    FetchBazosJob.set(wait: POLL_INTERVAL).perform_later
  rescue StandardError => e
    Rails.logger.error "[FetchBazosJob] Error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    FetchBazosJob.set(wait: POLL_INTERVAL).perform_later
  end

  private

  def fetch_newest_ads
    require 'net/http'
    require 'nokogiri'

    # Scrape the HTML page directly - sorted by newest (order=1)
    url = URI("#{BASE_URL}/?hledat=&rubriky=auto&cenaod=#{PRICE_FROM}&cenado=#{PRICE_TO}&order=1&kitx=ano")

    response = Net::HTTP.start(url.host, url.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
      req = Net::HTTP::Get.new(url.request_uri)
      req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      http.request(req)
    end

    return [] unless response.is_a?(Net::HTTPSuccess)

    doc = Nokogiri::HTML(response.body)
    listings = doc.css('div.inzeraty.inzeratyflex')

    return [] if listings.empty?

    # Extract listing data
    ads = listings.map do |listing|
      link = listing.at_css('h2.nadpis a')
      next unless link

      url_path = link['href']
      title = link.text.strip

      # Skip if it's a TOP/promoted listing marker only
      next if title.empty?

      full_url = "#{BASE_URL}#{url_path}"

      img = listing.at_css('img.obrazek')
      image_url = img ? img['src'] : nil

      price_el = listing.at_css('div.inzeratycena span[translate="no"]')
      price = price_el ? price_el.text.strip : nil

      loc_el = listing.at_css('div.inzeratylok')
      locality = loc_el ? loc_el.text.split("\n").first.strip : nil

      # Extract ID from URL
      id_match = url_path.match(/inzerat\/(\d+)/)
      api_id = id_match ? id_match[1] : nil

      {
        url: full_url,
        title: title,
        image_thumbnail: image_url,
        price_formatted: price,
        locality: locality,
        api_id: api_id
      }
    end.compact

    return [] if ads.empty?

    # Check which are new
    urls = ads.map { |ad| ad[:url] }
    existing = Car.where(url: urls).pluck(:url).to_set

    new_ads = ads.reject { |ad| existing.include?(ad[:url]) }
    return [] if new_ads.empty?

    # Save new cars
    cars_attributes = new_ads.map do |ad|
      {
        api_id: ad[:api_id],
        title: ad[:title],
        price_formatted: ad[:price_formatted],
        image_thumbnail: ad[:image_thumbnail],
        locality: ad[:locality],
        url: ad[:url],
        created_at: Time.current,
        updated_at: Time.current
      }
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
