# frozen_string_literal: true

module TestTypeHandlers
  HANDLERS = {
    "validity" => ->(adapter, test) {
      expr = test.expression
      expected = test.expected_valid
      return { "result" => "error", "notes" => "Missing expression" } unless expr

      parse_result = adapter.try_parse(expr, test.parse_options)
      actual_valid = parse_result["valid"]

      if actual_valid == expected
        { "result" => "pass", "actual" => { "valid" => actual_valid }, "api" => parse_result["api"] }
      else
        { "result" => "fail", "actual" => { "valid" => actual_valid },
          "notes" => "Expected #{expected}, got #{actual_valid}", "api" => parse_result["api"] }
      end
    },

    "parsing" => ->(adapter, test) {
      expr = test.expression
      return { "result" => "error", "notes" => "Missing expression" } unless expr

      expected_valid = test.expected_valid
      expected_components = test.expected_components

      parse_result = adapter.try_parse(expr, test.parse_options)

      if !parse_result["valid"] && expected_valid == false
        return { "result" => "pass", "actual" => { "valid" => false }, "api" => parse_result["api"] }
      end

      if !parse_result["valid"]
        return { "result" => "fail", "actual" => { "valid" => false, "error" => parse_result["error"] },
                 "api" => parse_result["api"] }
      end

      actual_components = adapter.extract_components(parse_result["parsed"])

      if components_match?(expected_components, actual_components)
        { "result" => "pass", "actual" => { "valid" => true, "components" => actual_components },
          "api" => parse_result["api"] }
      else
        { "result" => "fail", "actual" => { "valid" => true, "components" => actual_components },
          "notes" => "Component mismatch", "api" => parse_result["api"] }
      end
    },

    "generation" => ->(adapter, test) {
      given_components = test.given_components
      expected_expr = test.expected_expression
      return { "result" => "error", "notes" => "Missing components or expected expression" } unless given_components && expected_expr

      # If the test targets a basic-format requirement, signal that to the adapter
      # via the format hint. Adapters default to extended format otherwise.
      if test.basic_format? && !given_components.key?("format")
        given_components = given_components.merge("format" => "basic")
      end

      result = adapter.generate(given_components)
      return { "result" => "not-supported", "notes" => "Adapter cannot generate from given components" } if result.nil?

      if result["expression"] == expected_expr
        { "result" => "pass", "actual" => { "returned" => result["expression"] } }
      else
        { "result" => "fail", "actual" => { "returned" => result["expression"] },
          "notes" => "Expected '#{expected_expr}'" }
      end
    },

    "equivalence" => ->(adapter, test) {
      expr_a = test.expression_a
      expr_b = test.expression_b
      expected = test.expected_equivalent
      return { "result" => "error", "notes" => "Missing expressions" } unless expr_a && expr_b

      parse_a = adapter.try_parse(expr_a)
      parse_b = adapter.try_parse(expr_b)

      if !parse_a["valid"] || !parse_b["valid"]
        return { "result" => "not-supported",
                 "notes" => "Cannot parse one or both expressions",
                 "api" => [parse_a["api"], parse_b["api"]].join(", ") }
      end

      actual = adapter.equivalent?(parse_a["parsed"], parse_b["parsed"])

      if actual.nil?
        { "result" => "not-supported", "notes" => "Adapter cannot determine equivalence" }
      elsif actual == expected
        { "result" => "pass", "actual" => { "equivalent" => actual } }
      else
        { "result" => "fail", "actual" => { "equivalent" => actual }, "notes" => "Expected #{expected}" }
      end
    },

    "round_trip" => ->(adapter, test) {
      expr = test.expression
      return { "result" => "error", "notes" => "Missing expression" } unless expr

      parse_result = adapter.try_parse(expr, test.parse_options)
      unless parse_result["valid"]
        return { "result" => "fail", "notes" => "Parse failed: #{parse_result["error"]}",
                 "actual" => { "valid" => false }, "api" => parse_result["api"] }
      end

      components = adapter.extract_components(parse_result["parsed"])
      gen_result = adapter.generate(components)
      unless gen_result
        return { "result" => "not-supported",
                 "notes" => "Cannot generate from extracted components",
                 "actual" => { "components" => components } }
      end

      generated = gen_result["expression"]
      expected_expr = test.expected_expression

      if expected_expr
        if generated == expected_expr
          { "result" => "pass", "actual" => { "expression" => generated } }
        else
          { "result" => "fail", "actual" => { "expression" => generated },
            "notes" => "Expected '#{expected_expr}'" }
        end
      elsif generated == expr
        { "result" => "pass", "actual" => { "expression" => generated } }
      else
        reparsed = adapter.try_parse(generated)
        if reparsed["valid"] && adapter.equivalent?(parse_result["parsed"], reparsed["parsed"])
          { "result" => "pass", "actual" => { "expression" => generated },
            "notes" => "Semantically equivalent (different format)" }
        else
          { "result" => "fail", "actual" => { "expression" => generated },
            "notes" => "Expected '#{expr}'" }
        end
      end
    },

    "arithmetic" => ->(adapter, test) {
      adapter.run_arithmetic(test.raw)
    }
  }.freeze

  def self.run(adapter, test)
    type = test.test_type
    handler = HANDLERS[type]
    if handler
      handler.call(adapter, test)
    else
      { "result" => "error", "notes" => "Unknown test type: #{type}" }
    end
  end

  private

  def self.components_match?(expected, actual)
    return true unless expected
    return false unless actual

    expected.each do |key, exp_val|
      act_val = actual[key]
      if exp_val.is_a?(Hash)
        return false unless act_val.is_a?(Hash)
        return false unless components_match?(exp_val, act_val)
      elsif exp_val != act_val
        return false
      end
    end
    true
  end
end
