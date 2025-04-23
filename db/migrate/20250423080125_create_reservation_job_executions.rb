# frozen_string_literal: true

class CreateReservationJobExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :reservation_job_executions do |t|
      t.references :campground, null: false, foreign_key: true
      t.datetime :executed_at, null: false

      t.timestamps
    end
    add_index :reservation_job_executions, [ :campground_id, :executed_at ], unique: true
  end
end
