require "test_helper"

class CarTest < ActiveSupport::TestCase
  test "validates presence of url" do
    car = Car.new(title: "Test Car")
    assert_not car.valid?
    assert_includes car.errors[:url], "can't be blank"
  end

  test "validates presence of title" do
    car = Car.new(url: "https://example.com/car/1")
    assert_not car.valid?
    assert_includes car.errors[:title], "can't be blank"
  end

  test "validates uniqueness of url" do
    existing = cars(:bazos_car)
    car = Car.new(title: "Duplicate", url: existing.url)
    assert_not car.valid?
    assert_includes car.errors[:url], "has already been taken"
  end

  test "validates source inclusion" do
    car = Car.new(title: "Test", url: "https://example.com/1", source: "invalid")
    assert_not car.valid?
    assert_includes car.errors[:source], "is not included in the list"
  end

  test "allows nil source" do
    car = Car.new(title: "Test", url: "https://example.com/unique", source: nil)
    assert car.valid?
  end

  test "bazos scope returns only bazos cars" do
    bazos_cars = Car.bazos
    assert bazos_cars.all? { |car| car.source == "bazos" }
  end

  test "sauto scope returns only sauto cars" do
    sauto_cars = Car.sauto
    assert sauto_cars.all? { |car| car.source == "sauto" }
  end

  test "by_source with nil returns all cars" do
    assert_equal Car.count, Car.by_source(nil).count
  end

  test "by_source with bazos returns bazos cars" do
    assert_equal Car.bazos.count, Car.by_source("bazos").count
  end

  test "min_price filters correctly" do
    cars = Car.min_price(10000000) # 100,000 CZK in cents
    assert cars.all? { |car| car.price_cents.nil? || car.price_cents >= 10000000 }
  end

  test "max_price filters correctly" do
    cars = Car.max_price(10000000) # 100,000 CZK in cents
    assert cars.all? { |car| car.price_cents.nil? || car.price_cents <= 10000000 }
  end

  test "search finds cars by title" do
    results = Car.search("Octavia")
    assert results.any? { |car| car.title.include?("Octavia") }
  end

  test "search with nil returns all cars" do
    assert_equal Car.count, Car.search(nil).count
  end

  test "recent orders by created_at desc" do
    cars = Car.recent.to_a
    assert_equal cars, cars.sort_by(&:created_at).reverse
  end

  test "stats returns correct structure" do
    stats = Car.stats
    assert_includes stats.keys, :bazos_total
    assert_includes stats.keys, :bazos_today
    assert_includes stats.keys, :sauto_total
    assert_includes stats.keys, :sauto_today
  end

  test "parse_price_to_cents handles various formats" do
    assert_equal 15000000, Car.parse_price_to_cents("150 000 Kč")
    assert_equal 15000000, Car.parse_price_to_cents("150000 Kč")
    assert_equal 15000000, Car.parse_price_to_cents("150,000 Kč")
    assert_nil Car.parse_price_to_cents(nil)
    assert_nil Car.parse_price_to_cents("")
  end

  test "url_exists? returns true for existing url" do
    existing = cars(:bazos_car)
    assert Car.url_exists?(existing.url)
  end

  test "url_exists? returns false for new url" do
    assert_not Car.url_exists?("https://example.com/nonexistent")
  end
end
