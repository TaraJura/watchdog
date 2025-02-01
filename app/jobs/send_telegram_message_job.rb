class SendTelegramMessageJob < ApplicationJob
  queue_as :default

  def perform(title, full_link)
    TelegramBot.send_message(
      "Nové auto: \n[#{title}](#{full_link})",
      parse_mode: 'Markdown'
    )
  end
end
