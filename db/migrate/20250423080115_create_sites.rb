# frozen_string_literal: true

class CreateSites < ActiveRecord::Migration[8.0]
  def change
    create_table :sites do |t|
      t.references :campground, null: false, foreign_key: true
      t.references :site_type, null: false, foreign_key: true
      t.integer :site_no, null: false
      t.string :name

      t.timestamps
    end
    add_index :sites, %i[ campground_id site_no ], unique: true
    add_index :sites, :site_no
  end
end
