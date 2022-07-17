class AddNewHistoryColumn < ActiveRecord::Migration[7.0]
  def change
    add_column :histories, :cid, :integer
    add_column :histories, :tid, :integer
    ExternalService.create(name: 'tikr')
  end
end
