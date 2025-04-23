# frozen_string_literal: true

class ReservationSlot < ApplicationRecord
  belongs_to :reservation_job_execution
  belongs_to :site

  validates :reservation_job_execution_id, presence: true
  validates :site_id, presence: true
  validates :date, presence: true
  validates :time_slot, presence: true
  validates :status, presence: true
  validates :site_id, uniqueness: { scope: %i[ date time_slot reservation_job_execution_id ] }

  enum status: { close: 0, open: 1 }
end
