# philiprehberger-csv_builder

[![Tests](https://github.com/philiprehberger/rb-csv-builder/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-csv-builder/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-csv_builder.svg)](https://rubygems.org/gems/philiprehberger-csv_builder)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-csv-builder)](https://github.com/philiprehberger/rb-csv-builder/commits/main)

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

### Custom Delimiters

```ruby
builder = Philiprehberger::CsvBuilder.build(records, delimiter: "\t") do
  column :name
  column :email
end

puts builder.to_csv
# name	email
# Alice	alice@example.com
# Bob	bob@example.com
```

You can also set a custom quote character:

```ruby
builder = Philiprehberger::CsvBuilder.build(records, quote_char: "'") do
  column :name
  column :email
end
```

### Column Aliases

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name, header: 'Full Name'
  column :email, header: 'Email Address'
  column(:status, header: 'Active?') { |r| r[:active] ? 'Yes' : 'No' }
end

puts builder.to_csv
# Full Name,Email Address,Active?
# Alice,alice@example.com,Yes
# Bob,bob@example.com,No
```

### Filtering

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  column :email
  filter { |r| r[:active] }
end

puts builder.to_csv
# name,email
# Alice,alice@example.com
```

Multiple filters are combined with AND logic:

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  filter { |r| r[:active] }
  filter { |r| r[:name].start_with?('A') }
end
```

### Row Numbers

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  column :email
  row_number
end

puts builder.to_csv
# #,name,email
# 1,Alice,alice@example.com
# 2,Bob,bob@example.com
```

Customize the header label:

```ruby
row_number(header: 'Row')
```

### Sorting

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  column :email
  sort_by { |r| r[:name] }
end
```

Sort descending:

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  sort_by(direction: :desc) { |r| r[:name] }
end
```

### Streaming

```ruby
File.open('output.csv', 'w') do |file|
  builder = Philiprehberger::CsvBuilder.build(records) do
    column :name
    column :email
  end

  builder.to_io(file)
end
```

Works with any IO object, including `StringIO`:

```ruby
io = StringIO.new
builder.to_io(io)
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
| `CsvBuilder.build(records, delimiter:, quote_char:, &block)` | Build a CSV using the column DSL |
| `Builder#column(name, header:, &block)` | Define a column with optional alias and transform |
| `Builder#filter(&block)` | Filter records (block returns true to include) |
| `Builder#sort_by(direction:, &block)` | Sort records by block key (`:asc` or `:desc`) |
| `Builder#row_number(header:)` | Add auto-incrementing row number column |
| `Builder#to_csv` | Generate CSV as a string |
| `Builder#to_file(path)` | Write CSV to a file |
| `Builder#to_io(io)` | Stream CSV to any IO object |
| `Builder#headers` | Return column header names |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-csv-builder)

🐛 [Report issues](https://github.com/philiprehberger/rb-csv-builder/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-csv-builder/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
