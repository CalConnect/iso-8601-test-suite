# frozen_string_literal: true

# Graph utility — directed cycle detection using DFS.
# Used by validate's dependency graph phase.

module GraphUtil
  module_function

  def detect_cycles(adj)
    color = {}
    cycles = []

    dfs = lambda do |node, path|
      color[node] = :gray
      path << node
      (adj[node] || []).each do |neighbor|
        case color[neighbor]
        when :gray
          cycles << path + [neighbor]
        when nil
          dfs.call(neighbor, path)
        end
      end
      color[node] = :black
      path.pop
    end

    adj.keys.sort.each { |node| dfs.call(node, []) unless color[node] }
    cycles
  end
end
