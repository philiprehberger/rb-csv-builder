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
    end
  end
end
