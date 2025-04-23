# frozen_string_literal: true

class ReservationJobExecution < ApplicationRecord
  belongs_to :campground
  has_many :reservation_slots, dependent: :destroy

  validates :campground_id, presence: true
  validates :executed_at, presence: true
  validates :executed_at, uniqueness: { scope: :campground_id }
end
