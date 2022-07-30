# frozen_string_literal: true

module Philiprehberger
  module CsvBuilder
    # Represents a single column definition in a CSV builder
    class Column
      # @return [Symbol] the column name
      attr_reader :name

      # @return [Proc, nil] optional transform block
      attr_reader :transform

      # @param name [Symbol, String] the column name (also used as the record key)
      # @param header [String, nil] optional custom header label
      # @param transform [Proc, nil] optional block to transform the value
      def initialize(name, header: nil, &transform)
        @name = name.to_sym
        @custom_header = header
        @transform = block_given? ? transform : nil
      end

      # Extract the value for this column from a record
      #
      # @param record [Hash, Object] the source record
      # @return [String] the extracted and converted value
      def extract(record)
        value = if @transform
                  @transform.call(record)
                elsif record.is_a?(Hash)
                  record[@name] || record[@name.to_s]
                elsif record.respond_to?(@name)
                  record.send(@name)
                end

        value.to_s
      end

      # Return the header label for this column
      #
      # @return [String]
      def header
        @custom_header || @name.to_s
      end
    end
  end
end
