# lib/tasks/bazos.rake
namespace :bazos do
  desc "Fetch Bazos content"
  task fetch: :environment do
    Bazos.fetch_content
  end
end
