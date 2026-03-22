# frozen_string_literal: true

require_relative 'lib/philiprehberger/csv_builder/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-csv_builder'
  spec.version       = Philiprehberger::CsvBuilder::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']

  spec.summary       = 'Declarative CSV builder with column mapping and streaming output'
  spec.description   = 'Build CSV files from record collections using a declarative DSL with column definitions, ' \
                       'custom transforms, and file output support.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-csv-builder'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
