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
    # @yield [builder] the builder instance for defining columns
    # @yieldparam builder [Builder]
    # @return [Builder] the configured builder
    # @raise [Error] if no block is given
    def self.build(records, &block)
      raise Error, 'A block is required' unless block

      builder = Builder.new(records)
      builder.instance_eval(&block)
      builder
    end
  end
end
