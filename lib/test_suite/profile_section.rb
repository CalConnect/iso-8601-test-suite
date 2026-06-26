# frozen_string_literal: true

# Builds the profiles[] slice of the capability matrix.
#
# Each profile's slice has two halves:
#   * traceability[] — the conf-class → requirement → test chain, with
#     per-library detail for each test in the chain
#   * adapter_results[] — per-adapter aggregate stats across every
#     requirement that falls inside the profile
class ProfileSection
  # Per-profile organization logo path. Keys are profile IDs as they
  # appear in profiles/*.yaml; values are paths under site/public/logos.
  PROFILE_ORG_LOGOS = {
    "profile:rfc-3339"                => "/logos/ietf.svg",
    "profile:w3c-datetime"            => "/logos/w3c.svg",
    "profile:edtf-level-0"            => "/logos/loc.svg",
    "profile:edtf-level-1"            => "/logos/loc.svg",
    "profile:edtf-level-2"            => "/logos/loc.svg",
    "profile:iso-8601-1-complete"     => "/logos/iso-red.svg",
    "profile:iso-8601-1-core"         => "/logos/iso-red.svg",
    "profile:iso-8601-2-complete"     => "/logos/iso-red.svg",
    "profile:iso-8601-1-basic-format" => "/logos/iso-red.svg",
  }.freeze

  def initialize(ctx)
    @ctx = ctx
  end

  def build
    @ctx.index.profile_ids.filter_map do |pid|
      profile = @ctx.profile_by_id(pid)
      next unless profile

      ptests = @ctx.profile_tests[pid] || {}
      traceability = build_traceability(pid)
      req_ids_in_profile = collect_profile_req_ids(profile, traceability)

      {
        id: pid,
        name: profile.name,
        description: profile.description_stripped,
        source: profile.source,
        logo: PROFILE_ORG_LOGOS[pid],
        traceability_class_count: profile.traceability_count,
        additional_requirements: profile.additional_requirements.map { |r|
          { id: r["id"], statement: r["statement"]&.strip }
        },
        adapter_results: @ctx.adapters.map do |adefn|
          build_adapter_stats(adefn, req_ids_in_profile, ptests)
        end,
        traceability: traceability,
      }
    end
  end

  private

  def build_traceability(profile_id)
    @ctx.index.profile_traceability(profile_id).map do |tc|
      cc_id = tc.conformance_class
      explicit_reqs = tc.requirements

      by_req = tests_by_requirement(cc_id)
      by_req = by_req.select { |rid, _| explicit_reqs.include?(rid) } if explicit_reqs && !explicit_reqs.empty?

      req_chain = by_req.map do |rid, tests|
        req = @ctx.req_index[rid]
        {
          requirement_id: rid,
          statement: req&.statement,
          section: req&.section,
          format: req&.format,
          tests: tests.map { |t|
            { test_id: t.id, description: t.description, test_type: t.test_type,
              given: t.given, expect: t.expect }
          },
          per_library: @ctx.adapters.map { |adefn| build_per_library_detail(adefn, tests) },
        }
      end

      { id: cc_id, requirements: req_chain }
    end
  end

  def tests_by_requirement(cc_id)
    bare = @ctx.index.bare_id(cc_id)
    cc_file = @ctx.index.conf_class_ids[bare]
    cc_tests = if cc_file && @ctx.index.conf_class_ids.key?(bare)
      result = @ctx.store.load(cc_file)
      result.success? ? (result.data["tests"] || []).map { |t| Test.new(t) } : []
    else
      []
    end

    by_req = Hash.new { |h, k| h[k] = [] }
    cc_tests.each { |t| (@ctx.test_reqs[t.id] || []).each { |rid| by_req[rid] << t } }
    by_req
  end

  def build_per_library_detail(adefn, tests)
    runner = @ctx.runner_for(adefn[:id])
    results = runner.call(tests)
    status = TestStatus.from_results(results)
    {
      library_id: adefn[:id], status: status.to_matrix_symbol,
      pass: status.pass, total: status.total,
      details: tests.zip(results).map { |t, r|
        { test_id: t.id, result: r["result"],
          given: t.given, expect: t.expect,
          actual: r["actual"], api: r["api"], notes: r["notes"] }
      },
    }
  end

  def collect_profile_req_ids(profile, traceability)
    ids = traceability.flat_map { |cc| cc[:requirements].map { |r| r[:requirement_id] } }
    profile.additional_requirements.each { |ar| ids << ar["id"] }
    ids
  end

  def build_adapter_stats(adefn, req_ids_in_profile, ptests)
    runner = @ctx.runner_for(adefn[:id])
    test_pass = 0; test_total = 0
    req_pass = 0; req_partial = 0; req_fail = 0; req_not_supported = 0

    req_ids_in_profile.each do |rid|
      tests = ptests[rid]
      next unless tests && !tests.empty?

      results = runner.call(tests)
      status = TestStatus.from_results(results)
      test_pass += status.pass
      test_total += status.total

      case status.to_matrix_symbol
      when "pass"          then req_pass += 1
      when "fail"          then req_fail += 1
      when "not-supported" then req_not_supported += 1
      else                      req_partial += 1
      end
    end

    { id: adefn[:id], test_pass: test_pass, test_total: test_total,
      req_pass: req_pass, req_partial: req_partial, req_fail: req_fail,
      req_not_supported: req_not_supported }
  end
end
