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
      # @param row_sep [String] the line separator (default: "\n")
      # @param bom [Boolean] prepend UTF-8 BOM (default: false)
      # @param encoding [String] output encoding name (default: "UTF-8")
      # @param empty_value [String] placeholder for nil/empty values (default: "")
      def initialize(records, delimiter: ',', quote_char: '"', row_sep: "\n",
                     bom: false, encoding: 'UTF-8', empty_value: '')
        @records = records
        @columns = []
        @filters = []
        @validations = []
        @row_number_header = nil
        @delimiter = delimiter
        @quote_char = quote_char
        @row_sep = row_sep
        @sort_by = nil
        @sort_direction = :asc
        @limit_count = nil
        @offset_count = nil
        @footer_block = nil
        @header_transform = nil
        @bom = bom
        @encoding = encoding
        @empty_value = empty_value
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

      # Register a validation block for rows
      #
      # @yield [row] block that validates the row hash
      # @yieldparam row [Hash] column-name to value mapping
      # @return [self]
      def validate(&block)
        @validations << block
        self
      end

      # Register a proc applied to all column headers during rendering
      #
      # @yield [name] block that transforms a header name
      # @yieldparam name [String] the original header label
      # @return [self]
      def transform_header(&block)
        @header_transform = block
        self
      end

      # Shorthand for adding a footer row with a computed total for the named column
      #
      # @param column_name [Symbol, String] the column to total
      # @yield [values] optional block to compute the total (receives array of numeric values)
      # @return [self]
      def total(column_name, &block)
        col_name = column_name.to_sym
        @footer_block = lambda do |recs|
          columns.map do |col|
            if col.name == col_name
              values = recs.map { |r| col.extract(r, empty_value: @empty_value).to_f }
              block ? block.call(values) : values.sum
            else
              ''
            end
          end
        end
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
        base = base.map { |h| @header_transform.call(h) } if @header_transform
        @row_number_header ? [@row_number_header] + base : base
      end

      # Number of data rows the builder will emit (headers and footer excluded).
      # Applies all configured filters, sorts, offsets, and limits.
      #
      # @return [Integer]
      def row_count
        filtered_records.size
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
      # @raise [ValidationError] if any row fails validation
      def to_csv
        recs = filtered_records
        validate_rows!(recs) unless @validations.empty?
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

      # Alias for {#to_csv} so instances behave nicely with string interpolation.
      #
      # @return [String]
      def to_s
        to_csv
      end

      # Write the CSV to a file
      #
      # @param path [String] the output file path
      # @return [void]
      def to_file(path)
        File.binwrite(path, to_csv)
      end

      # Write the CSV to a file with an explicit mode. Useful for appending
      # to existing files or combining multiple builders into one file.
      #
      # When appending (`mode: 'ab'` / `'a'`), the header row and BOM from
      # subsequent writes are suppressed so the file keeps a single header.
      #
      # @param path [String] the output file path
      # @param mode [String] file open mode (default: "wb")
      # @return [void]
      def write_to(path, mode: 'wb')
        appending = mode.start_with?('a')
        if appending
          File.open(path, mode) { |f| write_body_rows(f) }
        else
          to_file(path)
        end
      end

      # Append data rows (no header, no BOM) to an existing CSV file.
      #
      # @param path [String] the output file path
      # @return [void]
      def append_to(path)
        write_to(path, mode: 'ab')
      end

      # Stream CSV to any IO object
      #
      # @param io [IO, StringIO] the IO object to write to
      # @return [void]
      # @raise [ValidationError] if any row fails validation
      def to_io(io)
        io.write("\xEF\xBB\xBF") if @bom
        recs = filtered_records
        validate_rows!(recs) unless @validations.empty?
        csv = CSV.new(io, **csv_options)
        csv << headers
        recs.each_with_index do |record, index|
          csv << build_row(record, index)
        end
        csv << @footer_block.call(recs) if @footer_block
      end

      # Return the CSV as an array of row arrays (headers + data + footer).
      #
      # @return [Array<Array>]
      # @raise [ValidationError] if any row fails validation
      def to_a
        recs = filtered_records
        validate_rows!(recs) unless @validations.empty?
        rows = [headers]
        recs.each_with_index { |record, index| rows << build_row(record, index) }
        rows << @footer_block.call(recs) if @footer_block
        rows
      end

      private

      # @return [Hash] CSV library options
      def csv_options
        { col_sep: @delimiter, quote_char: @quote_char, row_sep: @row_sep }
      end

      # Write only the data rows (and footer) to the given IO. Used by
      # {#write_to} / {#append_to} so subsequent appends don't duplicate
      # the header row.
      #
      # @param io [IO] the IO object to write to
      # @return [void]
      def write_body_rows(io)
        recs = filtered_records
        validate_rows!(recs) unless @validations.empty?
        csv = CSV.new(io, **csv_options)
        recs.each_with_index { |record, index| csv << build_row(record, index) }
        csv << @footer_block.call(recs) if @footer_block
      end

      # Validate all rows against registered validation blocks
      #
      # @param recs [Array] the filtered records
      # @return [void]
      # @raise [ValidationError] if any row fails validation
      def validate_rows!(recs)
        recs.each_with_index do |record, index|
          row_hash = @columns.to_h do |col|
            [col.name, col.extract(record, empty_value: @empty_value)]
          end
          @validations.each do |v|
            result = v.call(row_hash)
            raise ValidationError, "Row #{index + 1} failed validation" unless result
          rescue ValidationError
            raise
          rescue StandardError => e
            raise ValidationError, "Row #{index + 1} failed validation: #{e.message}"
          end
        end
      end

      # Build a single row array for the given record
      #
      # @param record [Object] the source record
      # @param index [Integer] zero-based row index
      # @return [Array]
      def build_row(record, index)
        row = @columns.map { |col| col.extract(record, empty_value: @empty_value) }
        @row_number_header ? [index + 1] + row : row
      end
    end
  end
end
