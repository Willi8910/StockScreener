class AddServicesTable < ActiveRecord::Migration[7.0]
  def change
    create_table :external_services do |t|
      t.string :name
      t.string :access_token
      t.datetime :last_update_access_token

      t.timestamps
    end
  end
end
