class CreateCars < ActiveRecord::Migration[7.1]
  def change
    create_table :cars do |t|
      t.string :title
      t.string :url
      t.string :api_id
      t.datetime :listed_at
      t.string :price_formatted
      t.string :currency
      t.string :image_thumbnail
      t.string :locality
      t.boolean :topped
      t.integer :image_width
      t.integer :image_height
      t.boolean :favourite

      t.index :api_id, unique: true
      t.index :url, unique: true
      t.timestamps
    end
  end
end
