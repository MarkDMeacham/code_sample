class CreateStatements < ActiveRecord::Migration
  def change
    create_table :statements do |t|
    	t.string :name
    	t.text :data, limit: 65535
      t.timestamps null: false
    end
  end
end
