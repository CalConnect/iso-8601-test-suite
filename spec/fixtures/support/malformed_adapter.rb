# frozen_string_literal: true
#
# Stub that emits a non-JSON line for every request — used to exercise
# ExecAdapter's JSON::ParserError rescue path.

loop do
  line = STDIN.gets
  break if line.nil?
  STDOUT.puts("this is not valid json")
  STDOUT.flush
end
