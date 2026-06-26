# frozen_string_literal: true

# Builds the requirements[] slice of the capability matrix.
#
# For every requirement referenced by at least one test, runs each test
# type group against every adapter (with declaration guard) and produces
# the per-(adapter, capability) status + per-test detail entries.
class RequirementsSection
  def initialize(ctx, on_progress: nil)
    @ctx = ctx
    @on_progress = on_progress
  end

  def build
    all_req_ids = @ctx.req_index.keys.sort
    (@ctx.req_tests.keys - all_req_ids).sort.each { |rid| all_req_ids << rid }

    all_req_ids.each_with_object([]) do |req_id, output|
      req = @ctx.req_index[req_id]
      tests_for_req = @ctx.req_tests[req_id]
      next if tests_for_req.nil? || tests_for_req.empty?

      entry = build_entry(req_id, req, tests_for_req.group_by { |t| t.test_type })
      output << entry
      @on_progress&.call(:requirement, req_id, req, @ctx.adapters, entry)
    end
  end

  private

  def build_entry(req_id, req, tests_by_type)
    entry = {
      id: req_id,
      category: req&.category || "Unknown",
      statement: req&.statement,
      format: req&.format,
      clause: req&.clause,
      section: req&.section,
      part: req&.part,
      pattern: req&.pattern,
      source_profile: req&.source_profile,
      profiles: @ctx.profile_req_map[req_id] || [],
      tests: {},
    }

    @ctx.adapters.each do |adefn|
      capabilities = build_capabilities(adefn, tests_by_type)
      entry[:tests][adefn[:id]] = capabilities unless capabilities.empty?
    end
    entry
  end

  def build_capabilities(adefn, tests_by_type)
    runner = @ctx.runner_for(adefn[:id])
    capabilities = {}

    tests_by_type.each do |test_type, tests|
      cap_key = CapabilityMatrix::TEST_TYPE_TO_CAPABILITY[test_type] || test_type
      results = runner.call(tests)
      status = TestStatus.from_results(results)

      next unless status.total.positive?

      capabilities[cap_key] = {
        status: status.to_matrix_symbol,
        pass: status.pass,
        total: status.total,
        details: tests.zip(results).map { |t, r|
          {
            test_id: t.id, description: t.description, test_type: t.test_type,
            given: t.given, expect: t.expect,
            result: r["result"], api: r["api"], notes: r["notes"], actual: r["actual"],
          }
        },
      }
    end
    capabilities
  end
end
