# frozen_string_literal: true

require 'set'

# Builds the libraries[] slice of the capability matrix.
#
# Each library entry is one adapter plus its declared conformance classes,
# its qualification notes, and the target-profile projection computed
# from its declarations and the already-built profile_results slice.
class LibrarySection
  def initialize(ctx, profile_results)
    @ctx = ctx
    @profile_results = profile_results
  end

  def build
    @ctx.adapters.map do |adefn|
      declared = @ctx.declared_classes[adefn.id] || []
      declared_profiles = @ctx.declared_profiles_for(adefn.id)
      targeted = target_profiles_for(declared, declared_profiles)
      notes = adefn.qualification_notes

      {
        id: adefn.id,
        name: adefn.name,
        family: adefn.family,
        logo: adefn.logo,
        language: adefn.language,
        version: adefn.version,
        declared_conformance_classes: declared,
        target_profiles: targeted,
        qualification_notes: notes,
      }
    end
  end

  private

  def target_profiles_for(declared, declared_profiles)
    if declared_profiles && !declared_profiles.empty?
      profile_set = declared_profiles.to_set
      return @profile_results.select { |p| profile_set.include?(p[:id]) }
                             .map { |p| { id: p[:id], name: p[:name] } }
    end

    return @profile_results.map { |p| { id: p[:id], name: p[:name] } } if declared.empty?

    declared_bare = declared.map { |d| @ctx.index.bare_id(d) }.to_set
    @profile_results.select { |p|
      tc = @ctx.index.profile_traceability(p[:id])
      tc.all? { |t| declared_bare.include?(@ctx.index.bare_id(t.conformance_class)) }
    }.map { |p| { id: p[:id], name: p[:name] } }
  end
end
