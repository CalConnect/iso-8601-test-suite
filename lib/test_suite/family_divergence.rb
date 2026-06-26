# frozen_string_literal: true

# Family-level divergence analysis for the capability matrix.
#
# Given a list of adapters that share a "family" (e.g. Ruby 3.0 / 3.1 / 3.2
# all in the "Ruby" family) and the per-requirement test results, this
# module reports where versions within the family disagree.
#
# Pure module: no IO, no instance state. Inputs in, deltas out.
module FamilyDivergence
  module_function

  def build(adapters, requirements)
    fam_adapters = adapters.group_by { |a| a[:family] }.map do |family, fam_members|
      range_label = build_family_range_label(fam_members)

      stats = if fam_members.size == 1
        { delta_count: 0, divergent_tests: [], per_version_delta: {}, stability: "single" }
      else
        compute_family_divergence(fam_members, requirements)
      end

      {
        family: family,
        logo: fam_members.first[:logo],
        language: fam_members.first[:language],
        version_count: fam_members.size,
        version_ids: fam_members.map { |a| a[:id] },
        range_label: range_label,
        **stats,
      }
    end
    fam_adapters
  end

  def compute_family_divergence(fam_adapters, requirements)
    divergent = []
    per_version_delta = fam_adapters.each_with_object(Hash.new(0)) { |a, h| h[a[:id]] = 0 }

    requirements.each do |req|
      tests = req[:tests]
      next unless tests

      test_map = Hash.new { |h, k| h[k] = {} }
      fam_adapters.each do |a|
        caps = tests[a[:id]]
        next unless caps
        caps.each do |cap_key, cap|
          (cap[:details] || []).each do |d|
            test_map[[cap_key, d[:test_id]]][a[:id]] = d[:result] if d.key?(:result)
          end
        end
      end

      test_map.each do |(cap_key, test_id), results_by_lib|
        next unless results_by_lib.size > 1
        unique = results_by_lib.values.uniq
        next unless unique.size > 1

        tally = results_by_lib.values.tally
        majority = tally.max_by { |_, c| c }.first

        divergent << {
          req_id: req[:id],
          cap_key: cap_key,
          test_id: test_id,
          results: results_by_lib.transform_values { |r| r || "unknown" },
        }

        results_by_lib.each do |lib_id, result|
          per_version_delta[lib_id] += 1 if result != majority
        end
      end
    end

    delta_count = divergent.size
    stability = case delta_count
                when 0 then "stable"
                when 1..5 then "minor"
                else "divergent"
                end

    { delta_count: delta_count, divergent_tests: divergent, per_version_delta: per_version_delta, stability: stability }
  end

  def build_family_range_label(fam_adapters)
    names = fam_adapters.map { |a| a[:name] }
    return names.first if names.size == 1

    labels = names.map { |n| version_label_for(n) }.compact
    return names.first if labels.empty?
    return labels.first if labels.uniq.size == 1

    numeric = labels.select { |l| l.match?(/\A\d+(\.\d+)*\z/) }
    if numeric.size == labels.size
      sorted = labels.sort_by { |l| l.split(".").map(&:to_i) }
      return "#{sorted.first} → #{sorted.last}"
    end

    "#{labels.first} → #{labels.last}"
  end

  def version_label_for(name)
    paren = name[/\(([^)]+)\)/, 1]
    return paren if paren
    m = name.match(/(\d+(?:\.\d+)*)/)
    m ? m[1] : nil
  end
end
