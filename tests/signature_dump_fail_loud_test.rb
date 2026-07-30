# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'ripper'

# scripts/signature_dump.rb feeds scripts/enumerate_signatures.py, which writes
# port_signatures.json -- the artifact the cross-port DRIFT gate compares against
# the Python oracle. Part of that dump is a "default index": every `def` under
# lib/ is parsed with Ripper so a literal parameter default can be recovered and
# reported (349 non-null defaults ride on it today).
#
# build_default_index used to skip an unparseable file SILENTLY:
#
#     sexp = parse_file(path)     # rescue StandardError -> nil
#     next if sexp.nil?           # <- no diagnostic, no exit code
#
# Every file under lib/ is valid Ruby by construction -- the FMT, LINT and TEST
# gates all parse the whole tree -- so a parse failure here never means "this
# file legitimately isn't Ruby". It means the reader is broken, the file is
# truncated, or it is unreadable. And the failure mode is the dangerous one: the
# dump still exits 0 and still looks well-formed, it is just SHORTER. Defaults
# that should have been recovered come back null, and DRIFT compares the port
# against a silently-shrunken surface. It fails SUCCESSFULLY -- the direction
# nobody checks.
#
# parse_file now raises with the offending path. This test proves it: a file
# Ripper cannot parse must produce a loud error NAMING the file, not a nil that
# the caller quietly skips.
class SignatureDumpFailLoudTest < Minitest::Test
  REPO = File.expand_path('..', __dir__)
  DUMP_SRC = File.read(File.join(REPO, 'scripts', 'signature_dump.rb'))

  # parse_file is a plain top-level method with no SDK dependencies, so it can be
  # lifted out of the script and exercised directly -- loading the whole script
  # would `require_relative '../lib/signalwire'` and build the real index.
  def parse_file_definition
    m = DUMP_SRC.match(/^def parse_file\(path\).*?^end$/m)

    refute_nil m, 'scripts/signature_dump.rb no longer defines parse_file(path)'
    m[0]
  end

  def sandbox
    Module.new.tap do |mod|
      mod.module_eval(parse_file_definition)
      mod.module_eval { module_function :parse_file }
    end
  end

  def test_parse_file_raises_naming_the_file_it_could_not_parse
    Dir.mktmpdir('sigdump-failloud') do |dir|
      path = File.join(dir, 'broken.rb')
      File.write(path, "def oops(  # deliberately unbalanced\n")

      err = assert_raises(StandardError) { sandbox.parse_file(path) }
      assert_match(/broken\.rb/, err.message,
                   'the failure must NAME the file that would not parse, so a ' \
                   'silently-shortened default index cannot pass as success')
    end
  end

  def test_parse_file_still_returns_a_sexp_for_valid_ruby
    Dir.mktmpdir('sigdump-failloud') do |dir|
      path = File.join(dir, 'fine.rb')
      File.write(path, "def fine(a = 1)\n  a\nend\n")

      assert_kind_of Array, sandbox.parse_file(path)
    end
  end
end
