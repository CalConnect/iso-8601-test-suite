# frozen_string_literal: true

class LoadResult
  def self.success(data)
    new(data: data, error: nil)
  end

  def self.failure(error_message)
    new(data: nil, error: error_message)
  end

  def success? = @error.nil?
  def failure? = !success?

  def data
    raise "Cannot access data on failed LoadResult" unless success?
    @data
  end

  def error_message
    raise "Cannot access error_message on successful LoadResult" unless failure?
    @error
  end

  private

  def initialize(data:, error:)
    @data = data
    @error = error
  end
end
