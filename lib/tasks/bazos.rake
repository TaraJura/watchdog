# lib/tasks/bazos.rake
namespace :bazos do
  desc "Fetch Bazos content"
  task fetch: :environment do
    Bazos.fetch_ads
  end
end
# rake bazos:fetch
