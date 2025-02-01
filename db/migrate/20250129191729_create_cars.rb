class CreateCars < ActiveRecord::Migration[7.1]
  def change
    create_table :cars do |t|
      t.string :title
      t.string :link

      t.timestamps
    end
  end
end
