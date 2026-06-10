# TODO.cleanup/20-tighten-profile-schema-given-expect

**Status:** DONE

`schema/profile.yaml` defines `additional_tests.given` and `additional_tests.expect` as
bare `type: object`, providing no structural validation. The conformance-class schema
(`schema/conformance-class.yaml`) has proper `oneOf` schemas with required fields for
given (expression, components, expression_a/b, operation) and expect (valid, expression,
equivalent). Profile additional tests should follow the same structure.

## Fix applied

Replaced bare `type: object` for `given` and `expect` in `schema/profile.yaml` with the
same `oneOf` definitions used in `schema/conformance-class.yaml`, ensuring profile tests
are validated with the same structural rules as conformance class tests.
