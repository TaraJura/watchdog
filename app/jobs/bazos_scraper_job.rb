class BazosScraperJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Bazos.fetch_content
  end
end
