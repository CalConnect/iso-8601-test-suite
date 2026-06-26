# frozen_string_literal: true

# Unified vocabulary for adapter test outcomes in the capability matrix.
#
# A TestStatus is constructed from a list of per-test result hashes and
# exposes a single canonical symbol that downstream slices (requirements,
# profiles, libraries, family divergence) all speak. This replaces the
# ad-hoc tally + classify_status pattern that was duplicated across three
# CapabilityMatrix methods.
#
# The matrix symbol is one of:
#   "pass"          — every test passed
#   "fail"          — every test failed or errored (with no passes)
#   "not-supported" — every test was not-supported (with no passes/failures)
#   "partial"       — some tests passed, some did not
#   "not-applicable"— no tests at all
class TestStatus
  PASS_RESULTS = ["pass"].freeze
  FAIL_RESULTS = ["fail", "error"].freeze
  NOT_SUPPORTED_RESULTS = ["not-supported"].freeze

  private_constant :PASS_RESULTS, :FAIL_RESULTS, :NOT_SUPPORTED_RESULTS

  attr_reader :pass, :fail, :not_supported, :total

  def initialize(pass:, fail:, not_supported:, total:)
    @pass = pass
    @fail = fail
    @not_supported = not_supported
    @total = total
  end

  def self.from_results(results)
    new(
      pass: results.count { |r| PASS_RESULTS.include?(result_string(r)) },
      fail: results.count { |r| FAIL_RESULTS.include?(result_string(r)) },
      not_supported: results.count { |r| NOT_SUPPORTED_RESULTS.include?(result_string(r)) },
      total: results.length,
    )
  end

  def self.result_string(r)
    r.is_a?(Hash) ? r["result"] : nil
  end
  private_class_method :result_string

  def not_applicable? = total.zero?
  def all_pass?        = total.positive? && pass == total
  def all_fail?        = total.positive? && fail == total
  def all_not_supported? = total.positive? && not_supported == total
  def partial?         = pass.positive? && pass < total

  def to_matrix_symbol
    return "not-applicable" if not_applicable?
    return "pass"          if all_pass?
    return "fail"          if all_fail?
    return "not-supported" if all_not_supported?
    return "partial"       if pass.positive?
    return "fail"          if fail.positive?
    "not-supported"
  end

  # Past-tense status vocabulary used in conformance-result.yaml for the
  # per-class and per-profile `status` field. The schema mandates the
  # enum [passed, failed, partial, not-supported]. Same classification
  # logic as to_matrix_symbol, different surface vocabulary.
  def to_result_status
    case to_matrix_symbol
    when "pass"          then "passed"
    when "fail"          then "failed"
    when "not-supported" then "not-supported"
    when "partial"       then "partial"
    else                      "not-supported"
    end
  end
end
