# frozen_string_literal: true

class ComponentVocabulary
  METADATA_KEYS = %w[description canonical_patterns].freeze

  def initialize(store)
    result = store.load(File.expand_path("../../schema/components.yaml", __dir__))
    @top_keys = Set.new
    @sub_keys = {}

    return if result.failure?

    data = result.data
    return unless data.is_a?(Hash)

    data.each do |name, defn|
      next if METADATA_KEYS.include?(name)
      next unless defn.is_a?(Hash)

      if container?(defn)
        defn.each do |child_name, child_defn|
          next unless child_defn.is_a?(Hash) && child_defn["keys"].is_a?(Hash)
          register(child_name, child_defn["keys"].keys)
        end
      elsif defn["keys"].is_a?(Hash)
        register(name, defn["keys"].keys)
      else
        @top_keys << name
        @sub_keys[name] ||= Set.new
      end
    end
  end

  def known_top_key?(key)
    @top_keys.include?(key)
  end

  def known_sub_key?(parent, key)
    @sub_keys.fetch(parent, nil)&.include?(key) || false
  end

  def top_keys
    @top_keys.to_a.freeze
  end

  def sub_keys(parent)
    @sub_keys[parent]&.to_a.freeze || [].freeze
  end

  private

  def register(name, keys)
    @top_keys << name
    @sub_keys[name] = Set.new(keys)
  end

  def container?(hash)
    return false if hash.key?("keys")
    hash.each do |_k, v|
      return false unless v.is_a?(Hash) && v["keys"].is_a?(Hash)
    end
    !hash.empty?
  end
end
