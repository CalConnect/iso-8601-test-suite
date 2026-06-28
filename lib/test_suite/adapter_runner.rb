# frozen_string_literal: true

# Executes a list of conformance tests against a single adapter, applying
# the per-adapter declaration guard.
#
# When the adapter has declared a non-empty set of conformance classes,
# tests whose owning class isn't in that set are short-circuited to a
# "not-supported" result without ever invoking the adapter. This encodes
# the Conformance Declaration Model (see memory) uniformly for every
# caller: requirements slice, profile traceability slice, library
# per-adapter stats.
class AdapterRunner
  DECLARATION_NOT_SUPPORTED = {
    "result" => "not-supported",
    "notes" => "Conformance class not declared",
  }.freeze

  def initialize(adapter, declared_bare:, index:)
    @adapter = adapter
    @declared_bare = declared_bare
    @index = index
    @result_cache = {}
  end

  def call(tests)
    tests.map { |t| @result_cache[t.id] ||= single_result(t) }
  end

  private

  def single_result(test)
    return DECLARATION_NOT_SUPPORTED.dup if declaration_blocks?(test)

    TestTypeHandlers.run(@adapter, test)
  rescue StandardError => e
    { "result" => "error", "notes" => e.message }
  end

  def declaration_blocks?(test)
    return false if @declared_bare.empty?

    cc_bare = @index.bare_id(@index.class_for_test(test.id) || "")
    !@declared_bare.include?(cc_bare)
  end
end
