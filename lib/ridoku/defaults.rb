#
# Base class for Component Generation
#

module Ridoku
  class PropertyDefaultsUndefined < StandardError
    attr_accessor :method
    def initialize(_method)
      self.method = _method
      super "Inheritors of 'ClassProperties' must define: #{method}"
    end
  end

  class ClassProperties
    attr_accessor :default, :required, :input

    def defaults(type, _input)
      self.input = _input
      
      fail ArgumentError.new("No default parameters for type: #{type}") unless
        default.key?(type)

      merge_input(type)
    end

    protected

    def merge_input(type)
      fail ArgumentError.new(":default and :required lack type: #{type}") unless
        default.key?(type) && required.key?(type)

      fail ArgumentError.new('Inputs :default and :user must be hashes!') unless
        default[type].is_a?(Hash) && input.is_a?(Hash)

      fail ArgumentError.new('Inputs :required must be an array!') unless
        required[type].is_a?(Array)

      type_default = Hash.clone(default[type])
      type_required = Hash.clone(required[type])

      required.each do |k|
        fail ArgumentError.new("User input reuqired: #{k}") unless
          input.key?(k)

        default[k] = input[k]
      end

      default
    end
  end
end