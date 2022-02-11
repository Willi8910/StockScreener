# frozen_string_literal: true

class Favourite < ApplicationRecord
  belongs_to :user
  belongs_to :stock

  default_scope { order(created_at: :desc) }
end
