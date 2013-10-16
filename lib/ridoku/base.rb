#
# Base Ridoku class for running commands

module Ridoku
  class InvalidConfig < StandardError
    attr_accessor :type, :error

    def initialize(type, error)
      self.type = type
      self.error = error
    end
  end

  class NoSshAccess < StandardError; end

  class Base
    class << self
      attr_accessor :config, :aws_client, :iam_client, :stack, :custom_json,
        :app, :layers, :instances, :account, :permissions

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

      def configure_opsworks_client
        opsworks = AWS::OpsWorks.new
        self.aws_client = opsworks.client
      end

      def fetch_stack(options = {})
        return stack if stack && !options[:force]

        configure_opsworks_client

        stack_name = config[:stack]

        fail InvalidConfig.new(:stack, :none) unless stack_name

        stacks = aws_client.describe_stacks
        self.stack = nil
        
        stacks[:stacks].each do |stck|
          self.stack = stck if stack_name == stck[:name]
        end

        fail InvalidConfig.new(:stack, :invalid) unless stack

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

      def fetch_app(options = {})
        return app if app && !options[:force]

        fetch_stack
        app_name = config[:app]

        fail InvalidConfig.new(:app, :none) unless app_name

        apps = aws_client.describe_apps(stack_id: stack[:stack_id])
        self.app = nil

        apps[:apps].each do |ap|
          self.app = ap if app_name == ap[:name]
        end

        fail InvalidConfig.new(:app, :invalid) unless stack

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

      def fetch_layers(shortname = :all, options = {})
        return layers if layers && !options[:force]
        fetch_stack

        self.layers = aws_client.describe_layers(stack_id: stack[:stack_id])
        if shortname != :all
          self.layers = self.layers[:layers].select do |layer|
            layer[:shortname] == shortname
          end
        end
      end

      def save_layer(layer, values)
        values = [values] unless values.is_a?(Array)

        return unless values.length > 0

        save_info = {
          layer_id: layer[:layer_id]
        }

        save_info.tap do |info|
          values.each do |val|
            info[val] = layer[val]
          end
        end

        aws_client.update_layer(save_info)
      end


      # 'lb' - load balancing layers
      # 'rails-app'
      # 'custom'
      def fetch_instances(shortname = :all, options = {})
        return instances if instances && !options[:force]
        if shortname != :all
          fetch_layers
          self.instances = []

          layers[:layers].each do |layer|
            if layer[:shortname] == shortname
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

      def fetch_account(options = {})
        return account if account && !options[:force]

        iam = AWS::IAM.new
        self.iam_client = iam.client

        self.account = iam_client.get_user
      end


      def fetch_permissions(options = {})
        fetch_stack
        fetch_account

        return permissions if permissions && !options[:force]

        self.permissions = aws_client.describe_permissions(
          iam_user_arn: account[:user][:arn],
          stack_id: stack[:stack_id]
        )
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

      def pretty_instances(io)
        inststr = []
        instances.each do |inst|
          val = "#{inst[:hostname]} [#{inst[:status]}]"
          inststr << io.colorize(val, [ :bold, inst[:status] == 'online' ? :green : :red ])
        end
        inststr
      end

      def deploy(deployment)
        fetch_stack
        fetch_app

        deployment[:stack_id] = stack[:stack_id]

        if config[:practice]
          $stdout.puts "Would run command: #{deployment[:command][:name]}"
          $stdout.puts 'On instances:'
          instances.each do |inst|
            next unless deployment[:instance_ids].index(inst[:instance_id]) != nil

            $stdout.puts "  #{inst[:hostname]}: #{$stdout.colorize(
              inst[:status], inst[:status] == 'online' ? :green : :red)}"
          end
        else
          aws_client.create_deployment(deployment)
          $stdout.puts $stdout.colorize('Command Sent', :green) if
            config[:verbose]
        end
      end
    end
  end
end  