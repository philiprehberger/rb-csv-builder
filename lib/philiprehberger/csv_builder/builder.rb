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
      def initialize(records)
        @records = records
        @columns = []
      end

      # Define a column
      #
      # @param name [Symbol, String] the column name
      # @yield [record] optional block to transform the value
      # @yieldparam record [Object] the source record
      # @return [self]
      def column(name, &)
        @columns << Column.new(name, &)
        self
      end

      # Return the header row
      #
      # @return [Array<String>]
      def headers
        @columns.map(&:header)
      end

      # Generate the CSV as a string
      #
      # @return [String]
      def to_csv
        CSV.generate do |csv|
          csv << headers
          @records.each do |record|
            csv << @columns.map { |col| col.extract(record) }
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
    end
  end
end
