class CreateTableStockRecommend < ActiveRecord::Migration[7.0]
  def change
    create_table :stock_recommends do |t|
      t.references :history
      t.decimal :rating
      t.timestamps
    end
  end
end
