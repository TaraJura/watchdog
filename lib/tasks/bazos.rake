# lib/tasks/bazos.rake
namespace :bazos do
  desc "Fetch Bazos content in parallel"

  task fetch_parallel: :environment do
    puts "Job started at #{Time.now}"

    threads = [
      Thread.new { Bazos.fetch_ads(price_from: 5000, price_to: 50000, element_chat_id: '@bazosbot1') },
      Thread.new { Bazos.fetch_ads(price_from: 50000, price_to: 100000, element_chat_id: '@bazossecondfetch') },
      Thread.new { Bazos.fetch_ads(price_from: 100000, price_to: 300000, element_chat_id: '@bazosthirdfetch') }
    ]

    threads.each(&:join) # Wait for all threads to finish
    puts "Job finished at #{Time.now}"
  end
end


# CHAT_ID = '@bazosbot1'
# CHAT_ID = '@bazossecondfetch'
# CHAT_ID = '@bazosthirdfetch'
