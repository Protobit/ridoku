#
# Base class for Component Generation
#

require 'active_support/core_ext/hash/deep_merge'

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
        Base.roles_configured?
    end

    def defaults_with_wizard(type, _input)
      defaults(type, _input, true)
    end

    def defaults(type, _input, wizard = false)
      self.input = _input
      
      fail ArgumentError.new("No default parameters for type: #{type}") unless
        default.key?(type)

      merge_input(type, wizard)
    end

    protected

    def merge_input(type, with_wizard = false)
      fail ArgumentError.new(":default and :required lack type: #{type}") unless
        default.key?(type) && required.key?(type)

      fail ArgumentError.new('Inputs :default, :required, and :user must be hashes!') unless
        default[type].is_a?(Hash) && input.is_a?(Hash) && required[type].is_a?(Hash)

      type_default = default[type].deep_merge(input)

      errors = []
      collect = {}

      required[type].each do |k|
        unless input.key?(k)
          errors << k
          collect[k] = required[k]
        end
      end

      if with_wizard
        ConfigWizard.fetch_input(type_default, required[type], warnings)
      else
        fail ArgumentError.new("User input required: #{errors}") if
          errors.length
      end

      type_default
    end
  end
end