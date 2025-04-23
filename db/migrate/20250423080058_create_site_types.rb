# frozen_string_literal: true

class CreateSiteTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :site_types do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :site_types, :name, unique: true
  end
end
