# frozen_string_literal: true

class CreateReservationSlots < ActiveRecord::Migration[8.0]
  def change
    create_table :reservation_slots do |t|
      t.references :reservation_job_execution, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.date :date, null: false
      t.time :time_slot, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end
    add_index :reservation_slots, %i[ site_id date time_slot reservation_job_execution_id ], unique: true, name: 'index_reservation_slots_on_site_and_datetime_and_exec'
  end
end
