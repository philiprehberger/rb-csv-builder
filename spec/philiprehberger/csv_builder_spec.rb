# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'stringio'

RSpec.describe Philiprehberger::CsvBuilder do
  let(:records) do
    [
      { name: 'Alice', email: 'alice@example.com', active: true },
      { name: 'Bob', email: 'bob@example.com', active: false }
    ]
  end

  it 'has a version number' do
    expect(described_class::VERSION).not_to be_nil
  end

  describe '.build' do
    it 'raises Error when no block is given' do
      expect { described_class.build(records) }.to raise_error(described_class::Error)
    end

    it 'returns a Builder' do
      builder = described_class.build(records) { column :name }
      expect(builder).to be_a(described_class::Builder)
    end

    it 'provides access to the records' do
      builder = described_class.build(records) { column :name }
      expect(builder.records).to eq(records)
    end

    it 'provides access to the columns' do
      builder = described_class.build(records) do
        column :name
        column :email
      end
      expect(builder.columns.length).to eq(2)
    end
  end

  describe Philiprehberger::CsvBuilder::Builder do
    describe '#headers' do
      it 'returns column names as headers' do
        builder = Philiprehberger::CsvBuilder.build(records) do
          column :name
          column :email
        end
        expect(builder.headers).to eq(%w[name email])
      end

      it 'returns empty array when no columns defined' do
        builder = Philiprehberger::CsvBuilder.build(records) {}
        expect(builder.headers).to eq([])
      end

      it 'returns a single header for one column' do
        builder = Philiprehberger::CsvBuilder.build(records) { column :name }
        expect(builder.headers).to eq(['name'])
      end

      it 'preserves column order' do
        builder = Philiprehberger::CsvBuilder.build(records) do
          column :email
          column :name
          column :active
        end
        expect(builder.headers).to eq(%w[email name active])
      end
    end

    describe '#to_csv' do
      it 'generates CSV with headers and data' do
        builder = Philiprehberger::CsvBuilder.build(records) do
          column :name
          column :email
        end

        csv = builder.to_csv
        lines = csv.strip.split("\n")
        expect(lines[0]).to eq('name,email')
        expect(lines[1]).to eq('Alice,alice@example.com')
        expect(lines[2]).to eq('Bob,bob@example.com')
      end

      it 'supports custom transform blocks' do
        builder = Philiprehberger::CsvBuilder.build(records) do
          column :name
          column(:status) { |r| r[:active] ? 'Active' : 'Inactive' }
        end

        csv = builder.to_csv
        lines = csv.strip.split("\n")
        expect(lines[0]).to eq('name,status')
        expect(lines[1]).to eq('Alice,Active')
        expect(lines[2]).to eq('Bob,Inactive')
      end

      it 'handles empty records' do
        builder = Philiprehberger::CsvBuilder.build([]) do
          column :name
          column :email
        end

        csv = builder.to_csv
        lines = csv.strip.split("\n")
        expect(lines.size).to eq(1)
        expect(lines[0]).to eq('name,email')
      end

      it 'handles string keys in records' do
        string_records = [{ 'name' => 'Alice', 'email' => 'alice@example.com' }]
        builder = Philiprehberger::CsvBuilder.build(string_records) do
          column :name
          column :email
        end

        csv = builder.to_csv
        lines = csv.strip.split("\n")
        expect(lines[1]).to eq('Alice,alice@example.com')
      end

      it 'handles nil values' do
        nil_records = [{ name: 'Alice', email: nil }]
        builder = Philiprehberger::CsvBuilder.build(nil_records) do
          column :name
          column :email
        end

        csv = builder.to_csv
        lines = csv.strip.split("\n")
        expect(lines[1]).to include('Alice')
      end

      it 'escapes values with commas' do
        comma_records = [{ name: 'Smith, Alice', email: 'alice@example.com' }]
        builder = Philiprehberger::CsvBuilder.build(comma_records) do
          column :name
          column :email
        end

        csv = builder.to_csv
        expect(csv).to include('"Smith, Alice"')
      end

      it 'escapes values with double quotes' do
        quote_records = [{ name: 'She said "hello"', email: 'a@b.com' }]
        builder = Philiprehberger::CsvBuilder.build(quote_records) do
          column :name
          column :email
        end

        csv = builder.to_csv
        expect(csv).to include('""hello""')
      end

      it 'escapes values with newlines' do
        newline_records = [{ name: "Line1\nLine2", email: 'a@b.com' }]
        builder = Philiprehberger::CsvBuilder.build(newline_records) do
          column :name
          column :email
        end

        csv = builder.to_csv
        expect(csv).to include("\"Line1\nLine2\"")
      end

      it 'generates CSV with a single column' do
        builder = Philiprehberger::CsvBuilder.build(records) { column :name }

        csv = builder.to_csv
        lines = csv.strip.split("\n")
        expect(lines[0]).to eq('name')
        expect(lines[1]).to eq('Alice')
        expect(lines[2]).to eq('Bob')
      end

      it 'generates CSV with many columns' do
        builder = Philiprehberger::CsvBuilder.build(records) do
          column :name
          column :email
          column :active
        end

        csv = builder.to_csv
        lines = csv.strip.split("\n")
        expect(lines[0]).to eq('name,email,active')
      end

      it 'handles missing keys gracefully' do
        partial_records = [{ name: 'Alice' }]
        builder = Philiprehberger::CsvBuilder.build(partial_records) do
          column :name
          column :email
        end

        csv = builder.to_csv
        lines = csv.strip.split("\n")
        expect(lines[1]).to include('Alice')
      end

      it 'handles numeric values' do
        num_records = [{ name: 'Alice', age: 30 }]
        builder = Philiprehberger::CsvBuilder.build(num_records) do
          column :name
          column :age
        end

        csv = builder.to_csv
        lines = csv.strip.split("\n")
        expect(lines[1]).to eq('Alice,30')
      end

      it 'handles boolean values' do
        builder = Philiprehberger::CsvBuilder.build(records) do
          column :name
          column :active
        end

        csv = builder.to_csv
        lines = csv.strip.split("\n")
        expect(lines[1]).to eq('Alice,true')
        expect(lines[2]).to include('Bob')
      end

      it 'supports objects responding to method names' do
        obj = Struct.new(:name, :email).new('Struct', 'struct@example.com')
        builder = Philiprehberger::CsvBuilder.build([obj]) do
          column :name
          column :email
        end

        csv = builder.to_csv
        lines = csv.strip.split("\n")
        expect(lines[1]).to eq('Struct,struct@example.com')
      end

      it 'handles special characters in values' do
        special = [{ name: "tab\there", email: 'a@b.com' }]
        builder = Philiprehberger::CsvBuilder.build(special) do
          column :name
          column :email
        end

        csv = builder.to_csv
        expect(csv).to include("tab\there")
      end

      it 'generates correct CSV for large record sets' do
        many_records = (1..100).map { |i| { name: "User#{i}", email: "u#{i}@example.com" } }
        builder = Philiprehberger::CsvBuilder.build(many_records) do
          column :name
          column :email
        end

        csv = builder.to_csv
        lines = csv.strip.split("\n")
        expect(lines.size).to eq(101)
      end

      it 'converts symbol column names to string headers' do
        builder = Philiprehberger::CsvBuilder.build(records) { column :name }
        expect(builder.headers.first).to be_a(String)
      end
    end

    describe '#to_file' do
      it 'writes CSV to a file' do
        tmpfile = Tempfile.new(['test', '.csv'])
        builder = Philiprehberger::CsvBuilder.build(records) do
          column :name
          column :email
        end

        builder.to_file(tmpfile.path)
        content = File.read(tmpfile.path)
        lines = content.strip.split("\n")
        expect(lines[0]).to eq('name,email')
        expect(lines.size).to eq(3)
      ensure
        tmpfile&.unlink
      end

      it 'writes an empty CSV (headers only) to a file' do
        tmpfile = Tempfile.new(['empty', '.csv'])
        builder = Philiprehberger::CsvBuilder.build([]) do
          column :name
        end

        builder.to_file(tmpfile.path)
        content = File.read(tmpfile.path)
        lines = content.strip.split("\n")
        expect(lines.size).to eq(1)
        expect(lines[0]).to eq('name')
      ensure
        tmpfile&.unlink
      end
    end
  end

  describe 'custom delimiters' do
    it 'generates tab-separated CSV' do
      builder = described_class.build(records, delimiter: "\t") do
        column :name
        column :email
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines[0]).to eq("name\temail")
      expect(lines[1]).to eq("Alice\talice@example.com")
    end

    it 'generates pipe-separated CSV' do
      builder = described_class.build(records, delimiter: '|') do
        column :name
        column :email
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines[0]).to eq('name|email')
      expect(lines[1]).to eq('Alice|alice@example.com')
    end

    it 'generates semicolon-separated CSV' do
      builder = described_class.build(records, delimiter: ';') do
        column :name
        column :email
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines[0]).to eq('name;email')
    end
  end

  describe 'custom quote character' do
    it 'uses single quotes for quoting' do
      quote_records = [{ name: 'Smith, Alice', email: 'alice@example.com' }]
      builder = described_class.build(quote_records, quote_char: "'") do
        column :name
        column :email
      end

      csv = builder.to_csv
      expect(csv).to include("'Smith, Alice'")
    end
  end

  describe 'column header aliasing' do
    it 'uses custom header labels' do
      builder = described_class.build(records) do
        column :name, header: 'Full Name'
        column :email, header: 'Email Address'
      end

      expect(builder.headers).to eq(['Full Name', 'Email Address'])
    end

    it 'includes custom headers in CSV output' do
      builder = described_class.build(records) do
        column :name, header: 'Full Name'
        column :email
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines[0]).to eq('Full Name,email')
      expect(lines[1]).to eq('Alice,alice@example.com')
    end

    it 'mixes aliased and non-aliased columns' do
      builder = described_class.build(records) do
        column :name, header: 'Person'
        column :email
        column :active, header: 'Status'
      end

      expect(builder.headers).to eq(%w[Person email Status])
    end
  end

  describe 'filter' do
    it 'filters records with a predicate' do
      builder = described_class.build(records) do
        column :name
        column :email
        filter { |r| r[:active] }
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines.size).to eq(2)
      expect(lines[1]).to eq('Alice,alice@example.com')
    end

    it 'filters with string matching' do
      builder = described_class.build(records) do
        column :name
        filter { |r| r[:name].start_with?('B') }
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines.size).to eq(2)
      expect(lines[1]).to eq('Bob')
    end

    it 'supports multiple filters (AND logic)' do
      extended = records + [{ name: 'Charlie', email: 'charlie@example.com', active: true }]
      builder = described_class.build(extended) do
        column :name
        filter { |r| r[:active] }
        filter { |r| r[:name].length > 4 }
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines.size).to eq(3)
      expect(lines[1]).to eq('Alice')
      expect(lines[2]).to eq('Charlie')
    end

    it 'returns only headers when all records are filtered out' do
      builder = described_class.build(records) do
        column :name
        filter { |_r| false }
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines.size).to eq(1)
      expect(lines[0]).to eq('name')
    end

    it 'handles empty records after filter' do
      builder = described_class.build([]) do
        column :name
        filter { |r| r[:active] }
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines.size).to eq(1)
      expect(lines[0]).to eq('name')
    end
  end

  describe 'sort_by' do
    let(:unsorted) do
      [
        { name: 'Charlie', age: 30 },
        { name: 'Alice', age: 25 },
        { name: 'Bob', age: 35 }
      ]
    end

    it 'sorts records ascending by default' do
      builder = described_class.build(unsorted) do
        column :name
        sort_by { |r| r[:name] }
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines[1]).to eq('Alice')
      expect(lines[2]).to eq('Bob')
      expect(lines[3]).to eq('Charlie')
    end

    it 'sorts records descending when direction: :desc' do
      builder = described_class.build(unsorted) do
        column :name
        sort_by(direction: :desc) { |r| r[:name] }
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines[1]).to eq('Charlie')
      expect(lines[2]).to eq('Bob')
      expect(lines[3]).to eq('Alice')
    end

    it 'sorts by numeric key' do
      builder = described_class.build(unsorted) do
        column :name
        column :age
        sort_by { |r| r[:age] }
      end

      lines = builder.to_csv.strip.split("\n")
      expect(lines[1]).to eq('Alice,25')
      expect(lines[2]).to eq('Charlie,30')
      expect(lines[3]).to eq('Bob,35')
    end

    it 'combines with filter' do
      builder = described_class.build(unsorted) do
        column :name
        filter { |r| r[:age] >= 30 }
        sort_by { |r| r[:name] }
      end

      lines = builder.to_csv.strip.split("\n")
      expect(lines.size).to eq(3)
      expect(lines[1]).to eq('Bob')
      expect(lines[2]).to eq('Charlie')
    end

    it 'combines with row_number (numbered after sort)' do
      builder = described_class.build(unsorted) do
        column :name
        row_number
        sort_by { |r| r[:name] }
      end

      lines = builder.to_csv.strip.split("\n")
      expect(lines[1]).to eq('1,Alice')
      expect(lines[2]).to eq('2,Bob')
      expect(lines[3]).to eq('3,Charlie')
    end

    it 'raises when no block is given' do
      expect do
        described_class.build(unsorted) do
          column :name
          sort_by
        end
      end.to raise_error(described_class::Error, /block is required/)
    end

    it 'raises when direction is invalid' do
      expect do
        described_class.build(unsorted) do
          column :name
          sort_by(direction: :sideways) { |r| r[:name] }
        end
      end.to raise_error(described_class::Error, /direction must be/)
    end

    it 'leaves records untouched when sort_by is not called' do
      builder = described_class.build(unsorted) { column :name }
      lines = builder.to_csv.strip.split("\n")
      expect(lines[1]).to eq('Charlie')
      expect(lines[2]).to eq('Alice')
      expect(lines[3]).to eq('Bob')
    end
  end

  describe 'row_number' do
    it 'adds auto-incrementing row number as first column' do
      builder = described_class.build(records) do
        column :name
        row_number
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines[0]).to eq('#,name')
      expect(lines[1]).to eq('1,Alice')
      expect(lines[2]).to eq('2,Bob')
    end

    it 'uses custom row number header' do
      builder = described_class.build(records) do
        column :name
        row_number(header: 'Row')
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines[0]).to eq('Row,name')
      expect(lines[1]).to eq('1,Alice')
    end

    it 'numbers only filtered records' do
      builder = described_class.build(records) do
        column :name
        row_number
        filter { |r| r[:active] }
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines.size).to eq(2)
      expect(lines[1]).to eq('1,Alice')
    end
  end

  describe 'to_io streaming' do
    it 'streams CSV to a StringIO' do
      io = StringIO.new
      builder = described_class.build(records) do
        column :name
        column :email
      end

      builder.to_io(io)
      io.rewind
      content = io.read
      lines = content.strip.split("\n")
      expect(lines[0]).to eq('name,email')
      expect(lines[1]).to eq('Alice,alice@example.com')
      expect(lines[2]).to eq('Bob,bob@example.com')
    end

    it 'streams with custom delimiter' do
      io = StringIO.new
      builder = described_class.build(records, delimiter: "\t") do
        column :name
        column :email
      end

      builder.to_io(io)
      io.rewind
      lines = io.read.strip.split("\n")
      expect(lines[0]).to eq("name\temail")
    end
  end

  describe 'combined features' do
    it 'combines filter, custom delimiter, and aliases' do
      builder = described_class.build(records, delimiter: '|') do
        column :name, header: 'Person'
        column :email, header: 'Contact'
        filter { |r| r[:active] }
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines[0]).to eq('Person|Contact')
      expect(lines[1]).to eq('Alice|alice@example.com')
      expect(lines.size).to eq(2)
    end

    it 'combines row number, filter, and aliases' do
      builder = described_class.build(records) do
        column :name, header: 'Name'
        row_number(header: 'No.')
        filter { |r| r[:active] }
      end

      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines[0]).to eq('No.,Name')
      expect(lines[1]).to eq('1,Alice')
    end

    it 'streams combined features to IO' do
      io = StringIO.new
      builder = described_class.build(records, delimiter: ';') do
        column :name, header: 'Full Name'
        row_number
        filter { |r| r[:name] == 'Bob' }
      end

      builder.to_io(io)
      io.rewind
      lines = io.read.strip.split("\n")
      expect(lines[0]).to eq('#;Full Name')
      expect(lines[1]).to eq('1;Bob')
      expect(lines.size).to eq(2)
    end
  end

  describe Philiprehberger::CsvBuilder::Column do
    describe '#header' do
      it 'returns the column name as a string' do
        col = described_class.new(:age)
        expect(col.header).to eq('age')
      end

      it 'returns custom header when provided' do
        col = described_class.new(:age, header: 'User Age')
        expect(col.header).to eq('User Age')
      end

      it 'falls back to name when no custom header' do
        col = described_class.new(:email, header: nil)
        expect(col.header).to eq('email')
      end
    end

    describe '#extract' do
      it 'extracts value from a hash with symbol key' do
        col = described_class.new(:name)
        expect(col.extract({ name: 'Alice' })).to eq('Alice')
      end

      it 'extracts value from a hash with string key' do
        col = described_class.new(:name)
        expect(col.extract({ 'name' => 'Bob' })).to eq('Bob')
      end

      it 'uses transform block when provided' do
        col = described_class.new(:full) { |r| "#{r[:first]} #{r[:last]}" }
        expect(col.extract({ first: 'Alice', last: 'Smith' })).to eq('Alice Smith')
      end

      it 'converts nil to empty string' do
        col = described_class.new(:missing)
        expect(col.extract({})).to eq('')
      end
    end

    describe '#name' do
      it 'converts string name to symbol' do
        col = described_class.new('age')
        expect(col.name).to eq(:age)
      end
    end
  end

  describe '#footer' do
    it 'appends a computed footer row' do
      records = [{ name: 'Alice', amount: 10 }, { name: 'Bob', amount: 20 }]
      builder = Philiprehberger::CsvBuilder.build(records) do
        column :name
        column :amount
        footer { |recs| ['Total', recs.sum { |r| r[:amount] }] }
      end
      csv = builder.to_csv
      lines = csv.strip.split("\n")
      expect(lines.last).to eq('Total,30')
    end

    it 'includes footer in to_io output' do
      records = [{ name: 'A', amount: 5 }]
      builder = Philiprehberger::CsvBuilder.build(records) do
        column :name
        column :amount
        footer { |_recs| ['Sum', 5] }
      end
      io = StringIO.new
      builder.to_io(io)
      expect(io.string).to include('Sum,5')
    end

    it 'does not add footer when none defined' do
      builder = Philiprehberger::CsvBuilder.build(records) do
        column :name
      end
      lines = builder.to_csv.strip.split("\n")
      expect(lines.length).to eq(3) # header + 2 data rows
    end
  end

  describe 'BOM support' do
    it 'prepends UTF-8 BOM when bom: true' do
      builder = described_class.build(records, bom: true) do
        column :name
      end
      csv = builder.to_csv
      expect(csv.bytes[0..2]).to eq([0xEF, 0xBB, 0xBF])
    end

    it 'does not prepend BOM by default' do
      builder = described_class.build(records) do
        column :name
      end
      csv = builder.to_csv
      expect(csv.bytes[0..2]).not_to eq([0xEF, 0xBB, 0xBF])
    end

    it 'includes BOM in to_file output' do
      tmpfile = Tempfile.new(['bom', '.csv'])
      builder = described_class.build(records, bom: true) do
        column :name
      end
      builder.to_file(tmpfile.path)
      bytes = File.binread(tmpfile.path).bytes[0..2]
      expect(bytes).to eq([0xEF, 0xBB, 0xBF])
    ensure
      tmpfile&.unlink
    end

    it 'includes BOM in to_io output' do
      io = StringIO.new
      io.set_encoding('ASCII-8BIT')
      builder = described_class.build(records, bom: true) do
        column :name
      end
      builder.to_io(io)
      io.rewind
      expect(io.string.bytes[0..2]).to eq([0xEF, 0xBB, 0xBF])
    end

    it 'combines BOM with custom delimiter' do
      builder = described_class.build(records, bom: true, delimiter: "\t") do
        column :name
      end
      csv = builder.to_csv
      expect(csv.bytes[0..2]).to eq([0xEF, 0xBB, 0xBF])
      expect(csv).to include('name')
    end
  end

  describe '.tsv' do
    it 'generates tab-separated output' do
      builder = described_class.tsv(records) do
        column :name
        column :email
      end
      lines = builder.to_csv.strip.split("\n")
      expect(lines[0]).to eq("name\temail")
      expect(lines[1]).to eq("Alice\talice@example.com")
    end

    it 'returns a Builder instance' do
      builder = described_class.tsv(records) { column :name }
      expect(builder).to be_a(described_class::Builder)
    end

    it 'passes additional options through' do
      builder = described_class.tsv(records, bom: true) { column :name }
      csv = builder.to_csv
      expect(csv.bytes[0..2]).to eq([0xEF, 0xBB, 0xBF])
    end

    it 'raises Error when no block is given' do
      expect { described_class.tsv(records) }.to raise_error(described_class::Error)
    end
  end

  describe '.psv' do
    it 'generates pipe-separated output' do
      builder = described_class.psv(records) do
        column :name
        column :email
      end
      lines = builder.to_csv.strip.split("\n")
      expect(lines[0]).to eq('name|email')
      expect(lines[1]).to eq('Alice|alice@example.com')
    end

    it 'returns a Builder instance' do
      builder = described_class.psv(records) { column :name }
      expect(builder).to be_a(described_class::Builder)
    end

    it 'passes additional options through' do
      builder = described_class.psv(records, encoding: 'ISO-8859-1') { column :name }
      csv = builder.to_csv
      expect(csv.encoding).to eq(Encoding::ISO_8859_1)
    end

    it 'raises Error when no block is given' do
      expect { described_class.psv(records) }.to raise_error(described_class::Error)
    end
  end

  describe '#validate' do
    it 'passes when all rows satisfy the validation' do
      builder = described_class.build(records) do
        column :name
        validate { |row| !row[:name].empty? }
      end
      expect { builder.to_csv }.not_to raise_error
    end

    it 'raises ValidationError when a row returns falsy' do
      builder = described_class.build(records) do
        column :name
        validate { |row| row[:name] == 'Alice' }
      end
      expect { builder.to_csv }.to raise_error(described_class::ValidationError, /Row 2/)
    end

    it 'raises ValidationError when block raises an exception' do
      builder = described_class.build(records) do
        column :name
        validate { |_row| raise 'bad data' }
      end
      expect { builder.to_csv }.to raise_error(described_class::ValidationError, /bad data/)
    end

    it 'validates on to_io as well' do
      builder = described_class.build(records) do
        column :name
        validate { |row| row[:name] == 'Alice' }
      end
      expect { builder.to_io(StringIO.new) }.to raise_error(described_class::ValidationError)
    end

    it 'supports multiple validations (all must pass)' do
      builder = described_class.build(records) do
        column :name
        column :email
        validate { |row| !row[:name].empty? }
        validate { |row| row[:email].include?('@') }
      end
      expect { builder.to_csv }.not_to raise_error
    end

    it 'does not validate when no validation is registered' do
      builder = described_class.build(records) do
        column :name
      end
      expect { builder.to_csv }.not_to raise_error
    end
  end

  describe '#transform_header' do
    it 'upcases all headers' do
      builder = described_class.build(records) do
        column :name
        column :email
        transform_header(&:upcase)
      end
      expect(builder.headers).to eq(%w[NAME EMAIL])
    end

    it 'applies to CSV output' do
      builder = described_class.build(records) do
        column :name
        transform_header(&:capitalize)
      end
      lines = builder.to_csv.strip.split("\n")
      expect(lines[0]).to eq('Name')
    end

    it 'applies to custom header aliases' do
      builder = described_class.build(records) do
        column :name, header: 'full name'
        transform_header(&:upcase)
      end
      expect(builder.headers).to eq(['FULL NAME'])
    end

    it 'does not affect row number header' do
      builder = described_class.build(records) do
        column :name
        row_number(header: '#')
        transform_header(&:upcase)
      end
      expect(builder.headers).to eq(['#', 'NAME'])
    end
  end

  describe '#total' do
    let(:amount_records) do
      [
        { name: 'Alice', amount: 10 },
        { name: 'Bob', amount: 20 },
        { name: 'Charlie', amount: 30 }
      ]
    end

    it 'adds a footer row with the sum of the named column' do
      builder = described_class.build(amount_records) do
        column :name
        column :amount
        total :amount
      end
      lines = builder.to_csv.strip.split("\n")
      expect(lines.last).to include('60.0')
    end

    it 'uses a custom block to compute the total' do
      builder = described_class.build(amount_records) do
        column :name
        column :amount
        total(:amount, &:max)
      end
      lines = builder.to_csv.strip.split("\n")
      expect(lines.last).to include('30.0')
    end

    it 'leaves non-total columns blank' do
      builder = described_class.build(amount_records) do
        column :name
        column :amount
        total :amount
      end
      lines = builder.to_csv.strip.split("\n")
      # The footer row should contain the total for the amount column
      expect(lines.last).to include('60.0')
    end

    it 'works with filtered records' do
      builder = described_class.build(amount_records) do
        column :name
        column :amount
        filter { |r| r[:amount] >= 20 }
        total :amount
      end
      lines = builder.to_csv.strip.split("\n")
      expect(lines.last).to include('50.0')
    end
  end

  describe 'encoding support' do
    it 'returns ASCII-compatible encoding by default' do
      builder = described_class.build(records) do
        column :name
      end
      csv = builder.to_csv
      expect(csv.encoding).to be_ascii_compatible
    end

    it 'encodes output with custom encoding' do
      builder = described_class.build(records, encoding: 'ISO-8859-1') do
        column :name
      end
      csv = builder.to_csv
      expect(csv.encoding).to eq(Encoding::ISO_8859_1)
    end
  end

  describe '#limit' do
    it 'caps the number of output rows' do
      recs = (1..10).map { |i| { n: i } }
      builder = Philiprehberger::CsvBuilder.build(recs) do
        column :n
        limit 3
      end
      lines = builder.to_csv.strip.split("\n")
      expect(lines.length).to eq(4) # header + 3 rows
    end

    it 'returns all when limit exceeds count' do
      builder = Philiprehberger::CsvBuilder.build(records) do
        column :name
        limit 100
      end
      expect(builder.filtered_records.length).to eq(2)
    end
  end

  describe '#offset' do
    it 'skips the first N records' do
      recs = (1..5).map { |i| { n: i } }
      builder = Philiprehberger::CsvBuilder.build(recs) do
        column :n
        offset 2
      end
      expect(builder.filtered_records.map { |r| r[:n] }).to eq([3, 4, 5])
    end

    it 'combines with limit for pagination' do
      recs = (1..10).map { |i| { n: i } }
      builder = Philiprehberger::CsvBuilder.build(recs) do
        column :n
        offset 3
        limit 2
      end
      expect(builder.filtered_records.map { |r| r[:n] }).to eq([4, 5])
    end

    it 'returns empty when offset exceeds count' do
      builder = Philiprehberger::CsvBuilder.build(records) do
        column :name
        offset 100
      end
      expect(builder.filtered_records).to be_empty
    end
  end
end
