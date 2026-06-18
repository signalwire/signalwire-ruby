# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

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
