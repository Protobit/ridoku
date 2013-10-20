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
    attr_accessor :default, :required, :input, :warnings

    def initialize
      fail StandardError.new('IAM/OpsWorks permission are not yet configured.') unless
        Ridoku::Base.roles_configured?
    end

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

      fail ArgumentError.new('Inputs :default, :required, and :user must be hashes!') unless
        default[type].is_a?(Hash) && input.is_a?(Hash) && required[type].is_a?(Hash)

      type_default = default[type].clone
      type_required = required[type].clone

      ap input
      errors = []
      required[type].each do |k|
        errors << k unless input.key?(k.to_s)
        default[k] = input[k.to_s]
      end

      fail ArgumentError.new("User input required: #{errors}") if errors.length

      default
    end
  end
end