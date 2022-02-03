# frozen_string_literal: true

class Stock < ApplicationRecord
  belongs_to :user

  default_scope { order(created_at: :desc) }
end
