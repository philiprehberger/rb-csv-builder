# philiprehberger-csv_builder

[![Tests](https://github.com/philiprehberger/rb-csv-builder/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-csv-builder/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-csv_builder.svg)](https://rubygems.org/gems/philiprehberger-csv_builder)
[![License](https://img.shields.io/github/license/philiprehberger/rb-csv-builder)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Declarative CSV builder with column mapping and streaming output

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-csv_builder"
```

Or install directly:

```bash
gem install philiprehberger-csv_builder
```

## Usage

```ruby
require "philiprehberger/csv_builder"

records = [
  { name: 'Alice', email: 'alice@example.com', active: true },
  { name: 'Bob', email: 'bob@example.com', active: false }
]

builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  column :email
end

puts builder.to_csv
# name,email
# Alice,alice@example.com
# Bob,bob@example.com
```

### Custom Transforms

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  column :email
  column(:status) { |r| r[:active] ? 'Active' : 'Inactive' }
end

puts builder.to_csv
# name,email,status
# Alice,alice@example.com,Active
# Bob,bob@example.com,Inactive
```

### File Output

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  column :email
end

builder.to_file('output.csv')
```

### Headers

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  column :email
end

builder.headers  # => ["name", "email"]
```

## API

| Method | Description |
|--------|-------------|
| `CsvBuilder.build(records, &block)` | Build a CSV using the column DSL |
| `Builder#column(name, &block)` | Define a column with optional transform |
| `Builder#to_csv` | Generate CSV as a string |
| `Builder#to_file(path)` | Write CSV to a file |
| `Builder#headers` | Return column header names |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
