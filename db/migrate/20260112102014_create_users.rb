class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :token
      t.string :name

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :token, unique: true
  end
end
