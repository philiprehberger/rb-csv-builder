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
      # @param bom [Boolean] prepend UTF-8 BOM (default: false)
      # @param encoding [String] output encoding name (default: "UTF-8")
      def initialize(records, delimiter: ',', quote_char: '"', bom: false, encoding: 'UTF-8')
        @records = records
        @columns = []
        @filters = []
        @row_number_header = nil
        @delimiter = delimiter
        @quote_char = quote_char
        @sort_by = nil
        @sort_direction = :asc
        @limit_count = nil
        @offset_count = nil
        @footer_block = nil
        @bom = bom
        @encoding = encoding
      end

      # Sort records before CSV output
      #
      # @param direction [Symbol] :asc (default) or :desc
      # @yield [record] block returning the sort key
      # @yieldparam record [Object] the source record
      # @return [self]
      # @raise [Error] if direction is not :asc or :desc
      def sort_by(direction: :asc, &block)
        raise Error, 'A block is required for sort_by' unless block
        raise Error, "direction must be :asc or :desc (got #{direction.inspect})" unless %i[asc
                                                                                            desc].include?(direction)

        @sort_by = block
        @sort_direction = direction
        self
      end

      # Limit the number of output rows
      #
      # @param n [Integer] maximum rows
      # @return [self]
      def limit(n)
        @limit_count = n
        self
      end

      # Skip the first N filtered/sorted records
      #
      # @param n [Integer] number of rows to skip
      # @return [self]
      def offset(n)
        @offset_count = n
        self
      end

      # Append a computed footer row after all data rows
      #
      # @yield [Array] filtered records
      # @yieldreturn [Array] footer row values
      # @return [self]
      def footer(&block)
        @footer_block = block
        self
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
        if @sort_by
          result = result.sort_by(&@sort_by)
          result = result.reverse if @sort_direction == :desc
        end
        result = result.drop(@offset_count) if @offset_count
        result = result.first(@limit_count) if @limit_count
        result
      end

      # Generate the CSV as a string
      #
      # @return [String]
      def to_csv
        recs = filtered_records
        csv_string = CSV.generate(**csv_options) do |csv|
          csv << headers
          recs.each_with_index do |record, index|
            csv << build_row(record, index)
          end
          csv << @footer_block.call(recs) if @footer_block
        end
        csv_string = csv_string.encode(@encoding) unless @encoding == 'UTF-8'
        @bom ? "\xEF\xBB\xBF#{csv_string}" : csv_string
      end

      # Write the CSV to a file
      #
      # @param path [String] the output file path
      # @return [void]
      def to_file(path)
        File.binwrite(path, to_csv)
      end

      # Stream CSV to any IO object
      #
      # @param io [IO, StringIO] the IO object to write to
      # @return [void]
      def to_io(io)
        io.write("\xEF\xBB\xBF") if @bom
        recs = filtered_records
        csv = CSV.new(io, **csv_options)
        csv << headers
        recs.each_with_index do |record, index|
          csv << build_row(record, index)
        end
        csv << @footer_block.call(recs) if @footer_block
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
