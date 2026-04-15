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

### TSV and PSV Output

Use the `tsv` and `psv` shorthands instead of passing `delimiter:` manually:

```ruby
# Tab-separated
builder = Philiprehberger::CsvBuilder.tsv(records) do
  column :name
  column :email
end

puts builder.to_csv
# name	email
# Alice	alice@example.com

# Pipe-separated
builder = Philiprehberger::CsvBuilder.psv(records) do
  column :name
  column :email
end

puts builder.to_csv
# name|email
# Alice|alice@example.com
```

Both accept the same options as `build` (e.g. `bom:`, `encoding:`).

### Row Validation

Register one or more validation blocks. Rows are checked before `to_csv`, `to_file`, or `to_io`. If any block returns falsy or raises, a `CsvBuilder::ValidationError` is raised:

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  column :email
  validate { |row| row[:email].include?('@') }
end

builder.to_csv  # raises ValidationError if any email is missing '@'
```

### Header Transforms

Apply a transformation to all column headers during rendering:

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :first_name
  column :last_name
  transform_header { |h| h.upcase }
end

builder.headers  # => ["FIRST_NAME", "LAST_NAME"]
```

### Total Rows

Add a footer row with a computed total for a named column:

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  column :amount
  total :amount
end

# Outputs a footer row: ,60.0
```

Pass a block for custom aggregation:

```ruby
total(:amount) { |values| values.max }
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

### Footer Row

Append a computed summary row after all data rows:

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  column(:amount) { |r| r[:amount] }
  footer { |recs| ['Total', recs.sum { |r| r[:amount] }] }
end
```

### Pagination

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  offset 10   # skip first 10 records
  limit 25    # output at most 25 rows
end
```

`offset` and `limit` are applied after filtering and sorting.

### Excel-Compatible Output (BOM)

Prepend a UTF-8 BOM so Excel opens the CSV with correct encoding:

```ruby
builder = Philiprehberger::CsvBuilder.build(records, bom: true) do
  column :name
  column :email
end

builder.to_file('export.csv')
```

### Custom Encoding

```ruby
builder = Philiprehberger::CsvBuilder.build(records, encoding: 'ISO-8859-1') do
  column :name
end
```

### Row Count

Get the number of rows that will be emitted (respects filters, sorts, offsets, and limits) without building the CSV:

```ruby
builder = Philiprehberger::CsvBuilder.build(records) do
  column :name
  filter { |r| r[:active] }
  limit 50
end

builder.row_count  # => 50
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

### Writing and Appending

`write_to` accepts an explicit open mode so you can overwrite or append:

```ruby
# Overwrite (default behaviour, same as to_file)
builder.write_to('output.csv')

# Append data rows only (no header, no BOM) to an existing file
builder.append_to('output.csv')

# Or explicitly
builder.write_to('output.csv', mode: 'ab')
```

`append_to` is handy for combining multiple builders into one file while keeping a single header row.

### Custom Line Separator

Use `row_sep:` to switch between Unix (`\n`, default), Windows (`\r\n`) or any other line ending:

```ruby
builder = Philiprehberger::CsvBuilder.build(records, row_sep: "\r\n") do
  column :name
  column :email
end
```

### Custom Empty Value

Replace `nil` and empty string values with a placeholder:

```ruby
records = [{ name: 'Alice', email: nil }]

builder = Philiprehberger::CsvBuilder.build(records, empty_value: 'N/A') do
  column :name
  column :email
end

puts builder.to_csv
# name,email
# Alice,N/A
```

### String and Array Conversion

```ruby
# to_s is an alias for to_csv (handy for string interpolation)
puts "CSV:\n#{builder}"

# to_a returns [headers, *rows, footer?] for programmatic use
builder.to_a
# => [["name", "email"], ["Alice", "alice@example.com"], ["Bob", "bob@example.com"]]
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
| `CsvBuilder.build(records, delimiter:, quote_char:, row_sep:, bom:, encoding:, empty_value:, &block)` | Build a CSV using the column DSL |
| `CsvBuilder.tsv(records, **options, &block)` | Shorthand for tab-separated output |
| `CsvBuilder.psv(records, **options, &block)` | Shorthand for pipe-separated output |
| `Builder#column(name, header:, &block)` | Define a column with optional alias and transform |
| `Builder#filter(&block)` | Filter records (block returns true to include) |
| `Builder#sort_by(direction:, &block)` | Sort records by block key (`:asc` or `:desc`) |
| `Builder#validate(&block)` | Register a row validation block; raises `ValidationError` on failure |
| `Builder#transform_header(&block)` | Register a proc applied to all column headers |
| `Builder#total(column, &block)` | Add a footer row with computed total for the named column |
| `Builder#footer(&block)` | Append a computed footer row (block receives filtered records) |
| `Builder#limit(n)` | Cap output to N rows |
| `Builder#offset(n)` | Skip first N filtered/sorted records |
| `Builder#row_number(header:)` | Add auto-incrementing row number column |
| `Builder#to_csv` | Generate CSV as a string |
| `Builder#to_s` | Alias for `to_csv` (enables string interpolation) |
| `Builder#to_a` | Return CSV as an array of row arrays (headers + data + footer) |
| `Builder#to_file(path)` | Write CSV to a file (overwrites) |
| `Builder#write_to(path, mode:)` | Write CSV with an explicit file mode (`'wb'` default, `'ab'` to append body only) |
| `Builder#append_to(path)` | Append data rows (no header, no BOM) to an existing CSV file |
| `Builder#to_io(io)` | Stream CSV to any IO object |
| `Builder#headers` | Return column header names |
| `Builder#row_count` | Number of data rows after filters, sorts, offsets, and limits |

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
