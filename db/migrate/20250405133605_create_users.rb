class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :line_user_id, null: false
      t.string :name
      t.string :profile_image_url
      t.string :email
      t.string :status_message
      t.boolean :is_active, default: true
      t.datetime :last_login_at

      t.timestamps
    end

    add_index :users, :line_user_id, unique: true
  end
end
