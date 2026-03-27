# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

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

  describe Philiprehberger::CsvBuilder::Column do
    describe '#header' do
      it 'returns the column name as a string' do
        col = described_class.new(:age)
        expect(col.header).to eq('age')
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
end
