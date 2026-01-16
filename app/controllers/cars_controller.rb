class CarsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:start_fetching]

  def index
    @tab = params[:tab] || 'bazos'

    # Base query - filter by source based on tab
    if @tab == 'bazos'
      @cars = Car.where("url LIKE ?", "%bazos%")
    elsif @tab == 'sauto'
      @cars = Car.where("url LIKE ?", "%sauto%")
    else
      @cars = Car.all
    end

    # Always sort by newest first
    @cars = @cars.order(created_at: :desc)

    # Filter by price range
    if params[:min_price].present?
      @cars = @cars.where("CAST(REPLACE(REPLACE(REPLACE(price_formatted, ' ', ''), 'Kč', ''), ',', '') AS INTEGER) >= ?", params[:min_price].to_i)
    end

    if params[:max_price].present?
      @cars = @cars.where("CAST(REPLACE(REPLACE(REPLACE(price_formatted, ' ', ''), 'Kč', ''), ',', '') AS INTEGER) <= ?", params[:max_price].to_i)
    end

    # Search by title
    if params[:search].present?
      @cars = @cars.where("title LIKE ?", "%#{params[:search]}%")
    end

    @total_count = @cars.count
    @cars = @cars.limit(params[:limit] || 100)

    # Stats for each portal
    @stats = {
      bazos_total: Car.where("url LIKE ?", "%bazos%").count,
      bazos_today: Car.where("url LIKE ?", "%bazos%").where("created_at >= ?", Date.today).count,
      sauto_total: Car.where("url LIKE ?", "%sauto%").count,
      sauto_today: Car.where("url LIKE ?", "%sauto%").where("created_at >= ?", Date.today).count
    }

    # Check if jobs are running
    @fetching_active = Sidekiq::Queue.new.size > 0 || Sidekiq::Workers.new.size > 0
  end

  def start_fetching
    # Start the fetch jobs if not already running
    FetchBazosJob.perform_later(0)
    FetchSautoJob.perform_later

    render json: { status: 'ok', message: 'Fetching started' }
  end

  def stats
    render json: {
      bazos_total: Car.where("url LIKE ?", "%bazos%").count,
      bazos_today: Car.where("url LIKE ?", "%bazos%").where("created_at >= ?", Date.today).count,
      sauto_total: Car.where("url LIKE ?", "%sauto%").count,
      sauto_today: Car.where("url LIKE ?", "%sauto%").where("created_at >= ?", Date.today).count
    }
  end
end
