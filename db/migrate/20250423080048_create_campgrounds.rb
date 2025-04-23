# frozen_string_literal: true

class CreateCampgrounds < ActiveRecord::Migration[8.0]
  def change
    create_table :campgrounds do |t|
      t.string :name, null: false
      t.string :location

      t.timestamps
    end
    add_index :campgrounds, :name, unique: true
  end
end
