class History < ActiveRecord::Migration[7.0]
  def change
    create_table :histories do |t|
      t.string :name
      t.text :data
      t.integer :search_count, default: 1
      t.integer :search_monthly, default: 1
      t.timestamps
    end
  end
end
