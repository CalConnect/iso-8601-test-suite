# frozen_string_literal: true

class Stats
  def initialize
    @errors = []
    @warnings = []
    @passed = 0
    @total_files = 0
  end

  def error(path, msg)
    @errors << { path: path, msg: msg }
  end

  def warn(path, msg)
    @warnings << { path: path, msg: msg }
  end

  def pass!
    @passed += 1
  end

  def file!
    @total_files += 1
  end

  def ok?
    @errors.empty?
  end

  def error_count_snapshot
    @errors.length
  end

  def errors
    @errors.dup.freeze
  end

  def warnings
    @warnings.dup.freeze
  end

  def passed
    @passed
  end

  def total_files
    @total_files
  end

  def savepoint
    snapshot = @errors.length
    yield
    added = @errors.length - snapshot
    @errors.pop(added) if added > 0
    added
  end
end
