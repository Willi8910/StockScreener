class CreateStocks < ActiveRecord::Migration[7.0]
  def change
    create_table :stocks do |t|
      t.string :name
      t.integer :value
      t.integer :pb_fair_value
      t.integer :pe_fair_value
      t.integer :benjamin_fair_value


      t.timestamps
    end
  end
end
