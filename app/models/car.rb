class Car < ApplicationRecord
  # Validations
  validates :url, presence: true, uniqueness: true
  validates :title, presence: true
  validates :source, inclusion: { in: %w[bazos sauto], allow_nil: true }

  # Scopes for filtering by source
  scope :bazos, -> { where(source: 'bazos') }
  scope :sauto, -> { where(source: 'sauto') }
  scope :by_source, ->(source) { source.present? ? where(source: source) : all }

  # Scopes for price filtering
  scope :min_price, ->(cents) { where('price_cents >= ?', cents) if cents.present? }
  scope :max_price, ->(cents) { where('price_cents <= ?', cents) if cents.present? }
  scope :price_range, ->(min_cents, max_cents) { min_price(min_cents).max_price(max_cents) }

  # Scopes for time filtering
  scope :today, -> { where('created_at >= ?', Date.current.beginning_of_day) }
  scope :recent, -> { order(created_at: :desc) }

  # Search scope
  scope :search, ->(query) { where('title LIKE ?', "%#{query}%") if query.present? }

  # Check if URL already exists (for deduplication)
  def self.url_exists?(url)
    exists?(url: url)
  end

  # Parse price string to cents (e.g., "150 000 Kč" -> 15000000)
  def self.parse_price_to_cents(price_str)
    return nil if price_str.blank?
    cleaned = price_str.gsub(/[^\d]/, '')
    cleaned.present? ? cleaned.to_i * 100 : nil
  end

  # Stats for dashboard
  def self.stats
    {
      bazos_total: bazos.count,
      bazos_today: bazos.today.count,
      sauto_total: sauto.count,
      sauto_today: sauto.today.count
    }
  end
end
