# Auto-start fetch jobs when the server boots
# Only run in production and when not in Sidekiq process
Rails.application.config.after_initialize do
  if Rails.env.production? && !defined?(Sidekiq::CLI)
    # Delay startup to ensure everything is loaded
    Thread.new do
      sleep 5
      Rails.logger.info "[StartFetchJobs] Auto-starting fetch jobs..."

      begin
        FetchBazosJob.perform_later
        FetchSautoJob.perform_later
        Rails.logger.info "[StartFetchJobs] Fetch jobs queued successfully"
      rescue => e
        Rails.logger.error "[StartFetchJobs] Failed to start jobs: #{e.message}"
      end
    end
  end
end
