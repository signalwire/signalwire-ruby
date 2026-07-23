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
  gem 'rubocop', '>= 1.80'
  gem 'rubocop-minitest', '>= 0.38'
  gem 'rubocop-performance', '>= 1.25'
end
