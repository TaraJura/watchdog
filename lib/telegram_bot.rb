require 'net/http'
require 'json'

class TelegramBot
  TOKEN = '7851699339:AAEU8fX6WAY6_2kO7eBZVWE8aVNwFBx0pcA'.freeze
  CHAT_ID = '@bazosbot1'.freeze

  def self.send_message(text, parse_mode: nil)
    uri = URI("https://api.telegram.org/bot#{TOKEN}/sendMessage")
    params = { chat_id: CHAT_ID, text: text }
    params[:parse_mode] = parse_mode if parse_mode

    Net::HTTP.post(uri, params.to_json, "Content-Type" => "application/json")
  end
end
# Car.all.map{|x| TelegramBot.send_message("New car: #{x.title} odkaz: #{x.link}")}
# CHAT_ID = '@bazosbot1'.freeze
# CHAT_ID = '1619339886'.freeze
