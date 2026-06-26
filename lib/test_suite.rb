# frozen_string_literal: true

# Entry point for the ISO 8601 Test Suite library.
# All modules are autoloaded — loaded on first reference, not eagerly.

lib_dir = File.dirname(__FILE__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

autoload :Test,             "test_suite/test"
autoload :LoadResult,       "test_suite/load_result"
autoload :YamlStore,        "test_suite/yaml_store"
autoload :SuiteIndex,       "test_suite/suite_index"
autoload :TestSuiteLoader,    "test_suite/test_suite_loader"
autoload :TestTypeHandlers,   "test_suite/test_type_handlers"
autoload :AdapterLoader,      "test_suite/adapter_loader"
autoload :AdapterNotFoundError, "test_suite/adapter_loader"
autoload :ExecAdapter,        "test_suite/exec_adapter"
autoload :Stats,              "test_suite/stats"
autoload :SchemaValidator,    "test_suite/schema_validator"
autoload :ComponentVocabulary, "test_suite/component_vocab"
autoload :GraphUtil,          "test_suite/graph_util"
autoload :Term,               "test_suite/term"
autoload :CapabilityMatrix,   "test_suite/capability_matrix"
autoload :SuiteValidations,   "test_suite/suite_validations"
