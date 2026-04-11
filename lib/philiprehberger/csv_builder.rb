# frozen_string_literal: true

require_relative 'csv_builder/version'
require_relative 'csv_builder/column'
require_relative 'csv_builder/builder'

module Philiprehberger
  module CsvBuilder
    class Error < StandardError; end

    # Build a CSV from records using a declarative DSL
    #
    # @param records [Array] the source records
    # @param delimiter [String] the column separator (default: ",")
    # @param quote_char [String] the quote character (default: '"')
    # @param bom [Boolean] prepend UTF-8 BOM for Excel compatibility (default: false)
    # @param encoding [String] output encoding name (default: "UTF-8")
    # @yield [builder] the builder instance for defining columns
    # @yieldparam builder [Builder]
    # @return [Builder] the configured builder
    # @raise [Error] if no block is given
    def self.build(records, delimiter: ',', quote_char: '"', bom: false, encoding: 'UTF-8', &block)
      raise Error, 'A block is required' unless block

      builder = Builder.new(
        records,
        delimiter: delimiter, quote_char: quote_char,
        bom: bom, encoding: encoding
      )
      builder.instance_eval(&block)
      builder
    end
  end
end
