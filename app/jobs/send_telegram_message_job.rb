class SendTelegramMessageJob < ApplicationJob
  queue_as :default

  def perform(full_link)
    TelegramBot.send_message(full_link)
  end
end
