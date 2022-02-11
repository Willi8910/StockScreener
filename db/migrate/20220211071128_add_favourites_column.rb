class AddFavouritesColumn < ActiveRecord::Migration[7.0]
  def change
    add_column :stocks, :favourite, :boolean, default: false
  end
end
