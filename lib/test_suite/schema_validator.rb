# frozen_string_literal: true

class SchemaValidator
  def initialize(stats, store, schema_resolver: SchemaRegistry.method(:schema_for))
    @stats = stats
    @store = store
    @schema_resolver = schema_resolver
  end

  def validate_file(data_file)
    schema_rel = @schema_resolver.call(data_file)
    if schema_rel.nil?
      @stats.warn(data_file, "No schema registered for this file path")
      return
    end

    schema_result = @store.load(schema_rel)
    if schema_result.failure?
      @stats.error(data_file, "Cannot parse schema: #{schema_result.error_message}")
      return
    end

    data_result = @store.load(data_file)
    if data_result.failure?
      @stats.error(data_file, "YAML parse error: #{data_result.error_message}")
      return
    end

    validate_node(data_result.data, schema_result.data, data_file, "")
  end

  private

  def validate_node(data, schema, file, path)
    return unless schema.is_a?(Hash)

    if schema.key?("type")
      expected = schema["type"]
      unless type_matches?(data, expected)
        @stats.error(file, "#{path_label(path)}: expected type #{expected}, got #{ruby_type(data)} (#{truncate(data.inspect, 60)})")
        return
      end
    end

    if schema.key?("required") && data.is_a?(Hash)
      schema["required"].each do |field|
        @stats.error(file, "#{path_label(path)}: missing required field '#{field}'") unless data.key?(field)
      end
    end

    if schema.key?("pattern") && data.is_a?(String)
      pattern = schema["pattern"]
      @stats.error(file, "#{path_label(path)}: value '#{truncate(data, 40)}' does not match pattern /#{pattern}/") unless data.match?(/#{pattern}/)
    end

    if schema.key?("enum") && schema["enum"].is_a?(Array)
      @stats.error(file, "#{path_label(path)}: value '#{truncate(data.inspect, 40)}' not in enum #{schema["enum"]}") unless schema["enum"].include?(data)
    end

    if schema.key?("properties") && data.is_a?(Hash)
      schema["properties"].each do |key, prop_schema|
        next unless data.key?(key)
        validate_node(data[key], prop_schema, file, "#{path}.#{key}")
      end
    end

    if schema.key?("items") && data.is_a?(Array)
      data.each_with_index { |item, idx| validate_node(item, schema["items"], file, "#{path}[#{idx}]") }
    end

    validate_one_of(data, schema["oneOf"], file, path) if schema.key?("oneOf")
  end

  def validate_one_of(data, alternatives, file, path)
    matches = 0
    alternatives.each do |alt|
      added = @stats.savepoint { validate_node(data, alt, file, path) }
      matches += 1 if added == 0
    end
    @stats.error(file, "#{path_label(path)}: does not match any oneOf alternative") if matches == 0
    @stats.warn(file, "#{path_label(path)}: matches multiple oneOf alternatives (#{matches})") if matches > 1
  end

  def type_matches?(data, expected)
    case expected
    when "object"  then data.is_a?(Hash)
    when "string"  then data.is_a?(String)
    when "boolean" then [true, false].include?(data)
    when "integer" then data.is_a?(Integer)
    when "number"  then data.is_a?(Numeric)
    when "array"   then data.is_a?(Array)
    else true
    end
  end

  def ruby_type(data)
    { Hash => "object", String => "string", TrueClass => "boolean", FalseClass => "boolean",
      Integer => "integer", Float => "number", Array => "array", NilClass => "null" }.fetch(data.class, data.class.to_s)
  end

  def path_label(path) = path.empty? ? "<root>" : path
  def truncate(str, max) = (s = str.to_s).length > max ? "#{s[0, max - 3]}..." : s
end
