Sidekiq::Cron::Job.create(
  name: 'BazosScraperJob - every minute',
  cron: '* * * * *', # Every minute
  class: 'BazosScraperJob'
)
