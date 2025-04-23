# frozen_string_literal: true

class SiteType < ApplicationRecord
  has_many :sites

  validates :name, presence: true, uniqueness: true
end
