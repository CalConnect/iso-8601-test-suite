# frozen_string_literal: true

require 'yaml'

class YamlStore
  def initialize
    @cache = {}
  end

  def load(path)
    return @cache[path] if @cache.key?(path)

    result = begin
      data = YAML.load_file(path, permitted_classes: [Symbol])
      LoadResult.success(data)
    rescue => e
      LoadResult.failure(e.message)
    end

    @cache[path] = result
    result
  end

  def schema_ref(data_file)
    lines = File.readlines(data_file, encoding: "UTF-8")
    ref_line = lines.find { |l| l.include?("yaml-language-server") && l.include?("$schema") }
    return nil unless ref_line

    match = ref_line.match(/\$schema=\s*(\S+)/) ||
            ref_line.match(/\$schema:\s*(\S+)/)
    return nil unless match

    schema_rel = match[1].sub(/:$/, "")
    base = File.dirname(data_file)
    schema_path = File.expand_path(schema_rel, base)
    File.exist?(schema_path) ? schema_path : nil
  end

  def files_in(*globs)
    globs.flat_map { |g| Dir.glob(g).sort }.uniq
  end
end
