#
# Base Ridoku class for running commands

module Ridoku
  class NoAppSpecified < StandardError; end
  class NoStackSpecified < StandardError; end

  class Base
    class << self
      attr_accessor :config, :aws_client, :stack, :custom_json, :app, :layers,
        :instances, :app_instance_names

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
        stack_name = config[:stack]

        fail NoStackSpecified.new unless stack_name

        stacks = aws_client.describe_stacks
        self.stack = nil

        stacks[:stacks].each do |stck|
          self.stack = stck if stack_name == stck[:name]
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

      def fetch_app
        fetch_stack unless stack

        app_name = config[:app]

        fail NoAppSpecified.new unless app_name

        apps = aws_client.describe_apps(stack_id: stack[:stack_id])
        self.app = nil

        apps[:apps].each do |ap|
          self.app = ap if app_name == ap[:name]
        end

        return app
      end

      def save_app(values)
        values = [values] unless values.is_a?(Array)
        unless app
          $stderr.puts "Unable to save information because no app is " +
            "specified."
          return
        end

        save_info = {
          app_id: app[:app_id]
        }

        save_info.tap do |info|
          values.each do |val|
            info[val] = app[val]
          end
        end

        aws_client.update_app(save_info)
      end

      def fetch_layers
        fetch_stack unless stack
        self.layers = aws_client.describe_layers(stack_id: stack[:stack_id])
      end

      # 'lb' - load balancing layers
      # 'rails-app'
      # 'custom'
      def fetch_instances(type = :all)
        if type != :all
          fetch_layers unless layers
          self.instances = []

          layers[:layers].each do |layer|
            if layer[:type] == type
              instance = aws_client.describe_instances(
                layer_id: layer[:layer_id])
              self.instances << instance[:instances]
            end
          end

          self.instances.flatten!
        else
          self.instances = aws_client.describe_instances(stack_id: stack[:stack_id])
        end
      end

      def valid_instances?(args)
        args = [args] unless args.is_a?(Array)
        return false if args.length == 0

        fetch_instances('rails-app')

        inst_names = instances.map do |inst|
          return false if args.index(inst[:hostname]) != nil &&
            inst[:status] != 'online'

          inst[:hostname]
        end

        args.each do |arg|
          return false if inst_names.index(arg) == nil
        end

        true
      end
    end
  end
end  