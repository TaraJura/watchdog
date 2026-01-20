# Auto-start fetch jobs when the server boots
# Runs in production by default, or when AUTO_START_FETCH=true in development
Rails.application.config.after_initialize do
  should_auto_start = Rails.env.production? || ENV['AUTO_START_FETCH'] == 'true'

  if should_auto_start && !defined?(Sidekiq::CLI)
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
  else
    Rails.logger.info "[StartFetchJobs] Auto-start disabled. Use the 'Start Fetching' button or set AUTO_START_FETCH=true"
  end
end
