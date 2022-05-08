# frozen_string_literal: true

class BaseService
  def self.perform(*args)
    new(*args).perform
  end

  def perform
    raise NotImplementedError, "#{self.class.name} must implement method perform"
  end
end
