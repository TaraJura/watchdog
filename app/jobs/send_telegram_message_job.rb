class SendTelegramMessageJob < ApplicationJob
  queue_as :default

  def perform(text, element_chat_id)
    TelegramBot.send_message(text, element_chat_id)
  end
end
