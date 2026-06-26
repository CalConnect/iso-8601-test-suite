# frozen_string_literal: true

require 'json'
require 'fileutils'

# Output projection seam for the capability matrix.
#
# Given one matrix payload (the full in-memory shape produced by
# CapabilityMatrix#generate), MatrixOutput can project two complementary
# shapes and write them to disk:
#
#   * project_summary(matrix) / write_summary — the small shape loaded
#     eagerly by the dashboard (status + counts, no per-test details,
#     no profile traceability chains).
#   * project_detail(matrix) / write_detail   — the large shape loaded
#     on demand (per-test details + profile traceability).
#
# clean_nils is the shared final pass: JSON cannot represent nil in a
# meaningful way for the dashboard, and the matrix legitimately omits
# fields like notes/actual/api when an adapter returns nothing useful.
module MatrixOutput
  module_function

  def write_summary(matrix, path)
    write_compact(project_summary(matrix), path)
  end

  def write_detail(matrix, path)
    write_compact(project_detail(matrix), path)
  end

  def project_summary(matrix)
    {
      generated_at: matrix[:generated_at],
      libraries: matrix[:libraries],
      family_stats: matrix[:family_stats],
      categories: matrix[:categories],
      profiles: matrix[:profiles].map { |prof|
        prof.reject { |k, _| k == :traceability }
      },
      requirements: matrix[:requirements].map { |req|
        req.to_h { |k, v| [k, k == :tests ? strip_test_details(v) : v] }
      },
    }
  end

  def project_detail(matrix)
    {
      requirements: matrix[:requirements].map { |req|
        details = {}
        req[:tests].each do |lib_id, caps|
          lib_details = {}
          caps.each { |cap_key, cap| lib_details[cap_key] = { details: cap[:details] } if cap[:details] }
          details[lib_id] = lib_details unless lib_details.empty?
        end
        { id: req[:id], tests: details } unless details.empty?
      }.compact,
      profiles: matrix[:profiles].map { |prof|
        { id: prof[:id], traceability: prof[:traceability] } if prof[:traceability]
      }.compact,
    }
  end

  def strip_test_details(tests)
    tests.transform_values { |caps|
      caps.transform_values { |cap|
        { status: cap[:status], pass: cap[:pass], total: cap[:total] }
      }
    }
  end

  def write_compact(data, path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.generate(clean_nils(data)))
  end

  def clean_nils(obj)
    case obj
    when Hash
      obj.each_with_object({}) { |(k, v), h| h[k] = clean_nils(v) unless v.nil? }
    when Array
      obj.map { |v| clean_nils(v) }
    else
      obj
    end
  end
end
