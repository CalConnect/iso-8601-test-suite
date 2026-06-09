# frozen_string_literal: true

require "tempfile"

REPO_ROOT = File.expand_path(File.join(__dir__, ".."))

module SpecHelpers
  def with_temp_file(content, extension = ".yaml")
    file = Tempfile.new(["test", extension])
    file.write(content)
    file.flush
    yield file.path
  ensure
    file.close!
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed

  config.include SpecHelpers
end

def fixture_path(*parts)
  File.join(File.dirname(__FILE__), "fixtures", *parts)
end

def repo_path(*parts)
  File.join(REPO_ROOT, *parts)
end
