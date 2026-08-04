# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# tzinfo (a gemspec runtime dep, used by the datetime skill) needs a timezone
# data source. On POSIX it reads the OS zoneinfo db; Windows and JRuby have none,
# so they need the pure-Ruby tzinfo-data gem or every zone lookup raises
# TZInfo::DataSourceNotFound. Windows consumers of the published gem must likewise
# add `gem 'tzinfo-data'` (documented in the datetime skill docs).
gem 'tzinfo-data', platforms: %i[windows mingw mswin x64_mingw jruby]

# Development dependencies (declared here, not in the gemspec, per RuboCop's
# Gemspec/DevelopmentDependencies — so consumers installing the gem don't pull
# the test/lint toolchain).
group :development, :test do
  gem 'minitest', '>= 5.0'
  gem 'rack-test', '>= 2.0'
  gem 'rake', '>= 13.0'
  # Lint/format quality floor (FMT + LINT gates in scripts/run-ci.sh).
  #
  # These carry an upper bound on the MINOR version, not just a floor. With an
  # open floor ('>= 1.80'), CI resolves the newest release while local runs use
  # the committed Gemfile.lock, so a rubocop release that adds or tightens a cop
  # turns CI red with no code change and local FMT/LINT cannot reproduce it.
  # That happened with 1.89.0, which tightened
  # Layout/MultilineMethodCallIndentation: local 1.88.0 reported 0 offenses on
  # the exact commit CI failed with 3. Bump these deliberately (and fix the new
  # offenses in the same commit) rather than letting CI float.
  gem 'rubocop', '>= 1.89', '< 1.90'
  gem 'rubocop-minitest', '>= 0.40', '< 0.41'
  gem 'rubocop-performance', '>= 1.26', '< 1.27'
end
