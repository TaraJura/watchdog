require 'net/http'
require 'uri'
require 'nokogiri'
require 'digest'

class Bazos
  def self.fetch_content
    offset = 0

    loop do
      # Build URL with current offset
      url = build_url(offset)

      # Fetch page content
      response = fetch_page(url)
      break unless response.is_a?(Net::HTTPSuccess)

      # Parse and save cars, break if 1300 page reached
      parse_and_save_cars(response.body)
      offset = 0 if offset > 1300

      puts offset

      offset += 20
    end
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
      host: 'auto.bazos.cz',
      path: path,
      query: URI.encode_www_form(base_params)
    )
  end

  def self.fetch_page(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.request(Net::HTTP::Get.new(url.request_uri))
  end

  def self.parse_and_save_cars(html)
    doc = Nokogiri::HTML(html)
    listings = doc.css('.inzeraty.inzeratyflex')

    listings.each do |listing|
      title = listing.css('h2.nadpis a').text.strip
      link = listing.css('h2.nadpis a').attr('href').value
      full_link = URI.join("https://auto.bazos.cz", link).to_s

      unless Car.exists?(link: full_link)
        Car.create(title: title, link: full_link)
        ::SendTelegramMessageJob.perform_later(title, full_link)
      end
    end
  end
end
