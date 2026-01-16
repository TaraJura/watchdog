class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "notifications_channel"
    Rails.logger.info "[NotificationsChannel] Client subscribed"
  end

  def unsubscribed
    Rails.logger.info "[NotificationsChannel] Client unsubscribed"
  end
end
