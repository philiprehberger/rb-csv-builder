# frozen_string_literal: true

require 'csv'
require_relative 'column'

module Philiprehberger
  module CsvBuilder
    # DSL builder for constructing CSV output from records
    class Builder
      # @return [Array<Column>] the defined columns
      attr_reader :columns

      # @return [Array] the source records
      attr_reader :records

      # @param records [Array] the source records
      # @param delimiter [String] the column separator (default: ",")
      # @param quote_char [String] the quote character (default: '"')
      def initialize(records, delimiter: ',', quote_char: '"')
        @records = records
        @columns = []
        @filters = []
        @row_number_header = nil
        @delimiter = delimiter
        @quote_char = quote_char
      end

      # Define a column
      #
      # @param name [Symbol, String] the column name
      # @param header [String, nil] optional custom header label
      # @yield [record] optional block to transform the value
      # @yieldparam record [Object] the source record
      # @return [self]
      def column(name, header: nil, &block)
        @columns << Column.new(name, header: header, &block)
        self
      end

      # Add a filter to exclude records
      #
      # @yield [record] block that returns true to include the record
      # @yieldparam record [Object] the source record
      # @return [self]
      def filter(&block)
        @filters << block
        self
      end

      # Add an auto-incrementing row number as the first column
      #
      # @param header [String] the header label for the row number column
      # @return [self]
      def row_number(header: '#')
        @row_number_header = header
        self
      end

      # Return the header row
      #
      # @return [Array<String>]
      def headers
        base = @columns.map(&:header)
        @row_number_header ? [@row_number_header] + base : base
      end

      # Return the filtered records
      #
      # @return [Array]
      def filtered_records
        result = @records
        @filters.each do |f|
          result = result.select(&f)
        end
        result
      end

      # Generate the CSV as a string
      #
      # @return [String]
      def to_csv
        CSV.generate(**csv_options) do |csv|
          csv << headers
          filtered_records.each_with_index do |record, index|
            csv << build_row(record, index)
          end
        end
      end

      # Write the CSV to a file
      #
      # @param path [String] the output file path
      # @return [void]
      def to_file(path)
        File.write(path, to_csv)
      end

      # Stream CSV to any IO object
      #
      # @param io [IO, StringIO] the IO object to write to
      # @return [void]
      def to_io(io)
        csv = CSV.new(io, **csv_options)
        csv << headers
        filtered_records.each_with_index do |record, index|
          csv << build_row(record, index)
        end
      end

      private

      # @return [Hash] CSV library options
      def csv_options
        { col_sep: @delimiter, quote_char: @quote_char }
      end

      # Build a single row array for the given record
      #
      # @param record [Object] the source record
      # @param index [Integer] zero-based row index
      # @return [Array]
      def build_row(record, index)
        row = @columns.map { |col| col.extract(record) }
        @row_number_header ? [index + 1] + row : row
      end
    end
  end
end
