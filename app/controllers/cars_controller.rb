class CarsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:start_fetching]

  def index
    @tab = params[:tab] || 'bazos'
    @cars = build_query
    @total_count = @cars.count
    @cars = @cars.limit(params[:limit] || 100)
    @stats = Car.stats
    @fetching_active = jobs_running?
  end

  def start_fetching
    FetchBazosJob.perform_later
    FetchSautoJob.perform_later
    render json: { status: 'ok', message: 'Fetching started' }
  end

  def stats
    render json: Car.stats
  end

  private

  def build_query
    Car.by_source(@tab == 'all' ? nil : @tab)
       .recent
       .min_price(price_to_cents(params[:min_price]))
       .max_price(price_to_cents(params[:max_price]))
       .search(params[:search])
  end

  def price_to_cents(price)
    return nil if price.blank?
    price.to_i * 100
  end

  def jobs_running?
    Sidekiq::Queue.new.size > 0 || Sidekiq::Workers.new.size > 0
  end
end
