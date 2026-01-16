# lib/tasks/bazos.rake
namespace :bazos do
  desc "Fetch Bazos content in parallel"

  task fetch_parallel: :environment do
    puts "Job started at #{Time.now}"

    threads = [
      Thread.new { Bazos.fetch_ads(price_from: 10000, price_to: 50000, element_chat_id: '@bazosfirstfetch') },
      Thread.new { Bazos.fetch_ads(price_from: 50000, price_to: 100000, element_chat_id: '@bazossecondfetch') },
      Thread.new { Bazos.fetch_ads(price_from: 100000, price_to: 300000, element_chat_id: '@bazosthirdfetch') },
      Thread.new { Sauto.start }
    ]

    threads.each(&:join) # Wait for all threads to finish
    puts "Job finished at #{Time.now}"
  end
end
