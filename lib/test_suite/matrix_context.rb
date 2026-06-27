# frozen_string_literal: true

# Cross-referenced context object passed between the CapabilityMatrix
# orchestrator and its section builders.
#
# The matrix generation walks the same six pieces of derived data across
# every output slice: adapters (with their loaded instances), per-adapter
# declared classes/profiles, the requirement index, the test-to-req
# inversions, and the per-profile test/req maps. MatrixContext bundles
# them so section builders take one argument instead of six.
class MatrixContext
  attr_reader :store, :index,
              :adapters, :declared_classes, :declared_profiles,
              :req_index, :req_tests, :class_tests,
              :profile_tests, :profile_req_map, :test_reqs

  def initialize(store:, index:, adapters:, declared_classes:, declared_profiles:,
                 req_index:, req_tests:, class_tests:, profile_tests:,
                 profile_req_map:, test_reqs:)
    @store             = store
    @index             = index
    @adapters          = adapters
    @declared_classes  = declared_classes
    @declared_profiles = declared_profiles
    @req_index         = req_index
    @req_tests         = req_tests
    @class_tests       = class_tests
    @profile_tests     = profile_tests
    @profile_req_map   = profile_req_map
    @test_reqs         = test_reqs
    @runner_cache = {}
  end

  def declared_bare_for(adapter_id)
    declared_classes[adapter_id]&.map { |d| index.bare_id(d) } || []
  end

  def runner_for(adapter_id)
    @runner_cache[adapter_id] ||= begin
      adefn = adapters.find { |a| a.id == adapter_id }
      AdapterRunner.new(
        adefn.adapter,
        declared_bare: declared_bare_for(adapter_id),
        index: index,
      )
    end
  end

  def profile_by_id(pid)
    index.profiles[pid]
  end

  def declared_profiles_for(adapter_id)
    declared_profiles[adapter_id] || []
  end
end
