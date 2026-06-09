# frozen_string_literal: true

class AdapterNotFoundError < StandardError; end

module AdapterLoader
  ADAPTERS_DIR = File.expand_path(File.join(File.dirname(__dir__), "..", "adapters"))

  def self.load(adapter_name)
    if adapter_name.start_with?("exec:")
      return ExecAdapter.new(adapter_name.sub("exec:", ""))
    end

    path = File.join(ADAPTERS_DIR, "#{adapter_name}.rb")
    unless File.exist?(path)
      raise AdapterNotFoundError,
        "Adapter not found: #{path}. Available: #{list.join(', ')}. " \
        "Or use: --adapter exec:<command> for an external adapter"
    end

    require File.expand_path(path)
    class_name = adapter_name.split("-").map(&:capitalize).join + "Adapter"
    Object.const_get(class_name).new
  end

  def self.list
    Dir.glob(File.join(ADAPTERS_DIR, "*.rb"))
      .map { |f| File.basename(f, ".rb") }
      .reject { |n| n == "TEMPLATE" }
      .sort
  end
end
