class PushNotificationService
  VAPID_SUBJECT = 'mailto:admin@watchdog.app'.freeze
  ICON_PATH = '/icon.svg'.freeze
  DEFAULT_PRICE = 'Cena na dotaz'.freeze

  SOURCES = {
    'bazos' => 'Bazos.cz',
    'sauto' => 'Sauto.cz'
  }.freeze

  class << self
    def send_new_car_notification(car)
      subscriptions = PushSubscription.all
      return if subscriptions.empty?

      message = build_notification_message(car)

      subscriptions.each do |subscription|
        send_notification(subscription, message)
      end
    rescue StandardError => e
      log_error("Error sending car notification", e)
    end

    private

    def build_notification_message(car)
      source_name = SOURCES[car[:source]] || car[:source].to_s.capitalize

      {
        title: "#{source_name} - Nový inzerát",
        body: format_notification_body(car),
        icon: ICON_PATH,
        image: car[:image_thumbnail],
        url: car[:url]
      }
    end

    def format_notification_body(car)
      price = car[:price_formatted].presence || DEFAULT_PRICE
      "#{car[:title]}\n#{price}"
    end

    def send_notification(subscription, message)
      payload = JSON.generate(message)
      command = build_web_push_command(subscription, payload)

      result = system(*command)

      handle_send_failure(subscription) unless result
    rescue StandardError => e
      log_error("Failed to send notification to subscription #{subscription.id}", e)
    end

    def build_web_push_command(subscription, payload)
      [
        'npx', 'web-push', 'send-notification',
        "--endpoint=#{subscription.endpoint}",
        "--key=#{subscription.p256dh}",
        "--auth=#{subscription.auth}",
        "--payload=#{payload}",
        "--vapid-subject=#{VAPID_SUBJECT}",
        "--vapid-pubkey=#{ENV['VAPID_PUBLIC_KEY']}",
        "--vapid-pvtkey=#{ENV['VAPID_PRIVATE_KEY']}"
      ]
    end

    def handle_send_failure(subscription)
      exit_status = $?.exitstatus
      log_error("Failed to send notification (exit code: #{exit_status})")

      # Remove subscription if endpoint returned 410 Gone
      subscription.destroy if exit_status == 1
    end

    def log_error(message, exception = nil)
      error_message = "[PushNotificationService] #{message}"
      error_message += ": #{exception.message}" if exception
      Rails.logger.error(error_message)
    end
  end
end
