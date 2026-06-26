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
    rescue StandardError => e
      LoadResult.failure(e.message)
    end

    @cache[full_path] = result
    result
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
