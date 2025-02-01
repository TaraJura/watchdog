class SendTelegramMessageJob < ApplicationJob
  queue_as :default

  def perform(title, full_link)
    TelegramBot.send_message(full_link)
  end
end
