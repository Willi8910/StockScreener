class AddBondValueToHistoryTable < ActiveRecord::Migration[7.0]
  def change
    add_column :external_services, :yog, :int
    add_column :external_services, :yoc, :int
    add_column :external_services, :obligation_last_updated, :datetime
    ExternalService.create(name: 'phei')
  end
end
