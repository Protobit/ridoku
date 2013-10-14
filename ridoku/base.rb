#
# Base Ridoku class for running commands

module Ridoku
  class Base
    class << self
      attr_accessor :config, :aws_client, :stack, :custom_json

      @config = {}

      def load_config(path)
        if File.exists?(path)
          File.open(path, 'r') do |file|
            self.config = JSON.parse(file.read, symbolize_names: true)
          end
        end

        self.config ||= {}
      end

      def save_config(path)
        File.open(path, 'w') do |file|
          file.write(@config.to_json)
        end
      end

      def fetch_stack
        app = config[:app]

        stacks = aws_client.describe_stacks
        self.stack = nil

        stacks[:stacks].each do |stck|
          self.stack = stck if app == stck[:name]
        end

        self.custom_json = JSON.parse(stack[:custom_json]) if stack

        return stack
      end

      def save_stack
        aws_client.update_stack(
          stack_id: stack[:stack_id],
          custom_json: custom_json.to_json,
          service_role_arn: stack[:service_role_arn]
        ) if stack
      end
    end
  end
end