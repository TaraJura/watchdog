class SimplifyCarsTable < ActiveRecord::Migration[7.1]
  def up
    # Add source column for efficient filtering (instead of URL LIKE queries)
    add_column :cars, :source, :string
    add_index :cars, :source

    # Add price_cents for efficient numeric filtering (instead of parsing price_formatted)
    add_column :cars, :price_cents, :integer
    add_index :cars, :price_cents

    # Populate source based on existing URLs
    execute <<-SQL
      UPDATE cars SET source = 'bazos' WHERE url LIKE '%bazos%'
    SQL
    execute <<-SQL
      UPDATE cars SET source = 'sauto' WHERE url LIKE '%sauto%'
    SQL

    # Populate price_cents from price_formatted
    # This handles formats like "150 000 Kč" or "150000 Kč"
    execute <<-SQL
      UPDATE cars SET price_cents = CAST(
        REPLACE(REPLACE(REPLACE(price_formatted, ' ', ''), 'Kč', ''), ',', '')
        AS INTEGER
      ) * 100
      WHERE price_formatted IS NOT NULL AND price_formatted != ''
    SQL

    # Remove unused columns
    remove_column :cars, :listed_at
    remove_column :cars, :currency
    remove_column :cars, :topped
    remove_column :cars, :image_width
    remove_column :cars, :image_height
    remove_column :cars, :favourite

    # Remove api_id index and column (url is sufficient for deduplication)
    remove_index :cars, :api_id
    remove_column :cars, :api_id
  end

  def down
    add_column :cars, :api_id, :string
    add_index :cars, :api_id, unique: true
    add_column :cars, :favourite, :boolean
    add_column :cars, :image_height, :integer
    add_column :cars, :image_width, :integer
    add_column :cars, :topped, :boolean
    add_column :cars, :currency, :string
    add_column :cars, :listed_at, :datetime

    remove_index :cars, :price_cents
    remove_column :cars, :price_cents
    remove_index :cars, :source
    remove_column :cars, :source
  end
end
