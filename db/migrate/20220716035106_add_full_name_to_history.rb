class AddFullNameToHistory < ActiveRecord::Migration[7.0]
  def change
    add_column :histories, :full_name, :string
  end
end
