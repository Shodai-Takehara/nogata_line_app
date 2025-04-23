# frozen_string_literal: true

class Site < ApplicationRecord
  belongs_to :campground
  belongs_to :site_type
  has_many :reservation_slots, dependent: :destroy

  validates :campground_id, presence: true
  validates :site_type_id, presence: true
  validates :site_no, presence: true, uniqueness: { scope: :campground_id }
end
