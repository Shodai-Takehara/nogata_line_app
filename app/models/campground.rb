# frozen_string_literal: true

class Campground < ApplicationRecord
  has_many :sites, dependent: :destroy
  has_many :reservation_job_executions, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
