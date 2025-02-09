require 'net/http'
require 'json'

class TelegramBot
  TOKEN = '7851699339:AAEU8fX6WAY6_2kO7eBZVWE8aVNwFBx0pcA'.freeze

  def self.send_message(text, element_chat_id)
    uri = URI("https://api.telegram.org/bot#{TOKEN}/sendMessage")
    params = { chat_id: element_chat_id, text: text, parse_mode: 'Markdown'}

    Net::HTTP.post(uri, params.to_json, "Content-Type" => "application/json")
  end
end
# Car.all.map{|x| TelegramBot.send_message("New car: #{x.title} odkaz: #{x.link}")}
# message = "[#{car.price_formatted}](#{car.url})"
# CHAT_ID = '1619339886'.freeze
# CHAT_ID = '@bazosbot1'.freeze
# CHAT_ID = '@bazossecondfetch'.freeze
# CHAT_ID = '@bazosthirdfetch'.freeze
# CHAT_ID = '@sautobot1'.freeze
