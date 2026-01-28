Rails.application.routes.draw do
  require 'sidekiq/web'

  mount Sidekiq::Web => '/sidekiq'
  mount ActionCable.server => '/cable'

  # Root path - car listings
  root "cars#index"

  # API endpoints
  post "start_fetching" => "cars#start_fetching"
  get "stats" => "cars#stats"

  # Push notifications
  post "push_subscriptions" => "push_subscriptions#create"
  get "vapid_public_key" => "push_subscriptions#vapid_public_key"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
