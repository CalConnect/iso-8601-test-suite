# frozen_string_literal: true

require 'yaml'

class YamlStore
  attr_reader :root

  def initialize(root: ".")
    @root = root
    @cache = {}
  end

  def load(path)
    full_path = resolve(path)
    return @cache[full_path] if @cache.key?(full_path)

    result = begin
      data = YAML.load_file(full_path, permitted_classes: [Symbol])
      LoadResult.success(data)
    rescue => e
      LoadResult.failure(e.message)
    end

    @cache[full_path] = result
    result
  end

  def schema_ref(data_file)
    full_path = resolve(data_file)
    lines = File.readlines(full_path, encoding: "UTF-8")
    ref_line = lines.find { |l| l.include?("yaml-language-server") && l.include?("$schema") }
    return nil unless ref_line

    match = ref_line.match(/\$schema=\s*(\S+)/) ||
            ref_line.match(/\$schema:\s*(\S+)/)
    return nil unless match

    schema_rel = match[1].sub(/:$/, "")
    base = File.dirname(full_path)
    schema_path = File.expand_path(schema_rel, base)
    File.exist?(schema_path) ? schema_path : nil
  end

  def files_in(*globs)
    prefix = @root == "." ? nil : @root
    globs.flat_map do |g|
      pattern = prefix ? File.join(prefix, g) : g
      Dir.glob(pattern).sort
    end.uniq
  end

  private

  def resolve(path)
    File.absolute_path(path, @root)
  end
end
