# frozen_string_literal: true

class AdapterNotFoundError < StandardError; end

module AdapterLoader
  ADAPTERS_DIR = File.expand_path(File.join(File.dirname(__dir__), "..", "adapters"))

  def self.load(adapter_name)
    if adapter_name.start_with?("exec:")
      return ExecAdapter.new(adapter_name.sub("exec:", ""))
    end

    path = resolve_adapter_path(adapter_name)
    unless path
      raise AdapterNotFoundError,
        "Adapter not found: #{adapter_name}. Available: #{list.join(', ')}. " \
        "Or use: --adapter exec:<command> for an external adapter"
    end

    require File.expand_path(path)
    class_name = adapter_name.split("-").map(&:capitalize).join + "Adapter"
    Object.const_get(class_name).new
  end

  def self.resolve_adapter_path(adapter_name)
    # Top-level: adapters/{name}.rb
    top = File.join(ADAPTERS_DIR, "#{adapter_name}.rb")
    return top if File.exist?(top)
    # Language subfolder: ruby-date → adapters/ruby/date.rb
    if adapter_name =~ /\A([a-z]+)-(.+)\z/
      sub = File.join(ADAPTERS_DIR, $1, "#{$2}.rb")
      return sub if File.exist?(sub)
    end
    nil
  end

  def self.list
    top_level = Dir.glob(File.join(ADAPTERS_DIR, "*.rb"))
      .map { |f| File.basename(f, ".rb") }
      .reject { |n| n == "TEMPLATE" }
    nested = Dir.glob(File.join(ADAPTERS_DIR, "/*/*.rb")).map do |f|
      dir = File.basename(File.dirname(f))
      base = File.basename(f, ".rb")
      "#{dir}-#{base}"
    end
    (top_level + nested).sort
  end
end
