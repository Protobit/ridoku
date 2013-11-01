#
# Base Ridoku class for running commands

require 'aws'
require 'awesome_print'

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
        :app, :layers, :instances, :account, :permissions, :stack_list,
        :app_list, :layer_list, :instance_list, :account_id, :ec2_client

      @config = {}

      POSTGRES_GROUP_NAME = 'Ridoku-PostgreSQL-Server'

      def load_config(path)
        if File.exists?(path)
          File.open(path, 'r') do |file|
            self.config = JSON.parse(file.read, symbolize_names: true)
          end
        end

        self.config ||= {}
      end

      def save_config(path, limit = [:app, :stack, :ssh_key, :local_init,
        :shell_user, :service_arn, :instance_arn])
        save = {}
        if limit.length
          limit.each do |lc|
            save[lc] = config[lc]
          end
        else
          save = config
        end
        File.open(path, 'w') do |file|
          file.write(save.to_json)
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

        self.stack_list = aws_client.describe_stacks[:stacks]
        self.stack = nil
        
        stack_list.each do |stck|
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

        self.app_list = aws_client.describe_apps(stack_id: stack[:stack_id])[:apps]
        self.app = nil

        app_list.each do |ap|
          self.app = ap if app_name == ap[:name]
        end

        fail InvalidConfig.new(:app, :invalid) unless app

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

      def fetch_layer(shortname = :all, options = {})
        return layers if layers && !options[:force]
        fetch_stack

        self.layers = self.layer_list = aws_client.describe_layers(
          stack_id: stack[:stack_id])[:layers]
        if shortname != :all
          self.layers = self.layers.select do |layer|
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
      def fetch_instance(shortname = :all, options = {})
        return instances if instances && !options[:force]

        fetch_stack
        self.instance_list = self.instances =
          aws_client.describe_instances(stack_id: stack[:stack_id])[:instances]

        if shortname != :all
          fetch_layer
          self.instances = []

          layer_list.each do |layer|
            if layer[:shortname] == shortname
              instance = aws_client.describe_instances(
                layer_id: layer[:layer_id])
              self.instances << instance[:instances]
            end
          end

          self.instances.flatten!
        end
      end

      def configure_iam_client
        return if self.iam_client

        iam = AWS::IAM.new
        self.iam_client = iam.client
      end

      def configure_ec2_client
        return if self.ec2_client

        self.ec2_client = AWS::EC2.new
      end

      def postgresql_group_exists?(region = 'us-west-1')
        configure_ec2_client

        ec2_client.security_groups.filter('group-name', POSTGRES_GROUP_NAME).length > 0
      end

      def update_pg_security_groups_in_all_regions
        AWS.regions.each do |region|
          $stdout.puts "Checking region: #{region.name}"
          update_pg_security_group(region.ec2)
        end
      end

      def update_pg_security_group(client = self.ec2_client)
        fetch_stack

        port = 5432

        if custom_json.key?(:postgresql) &&
          custom_json[:postgresql].key?(:config)
          custom_json[:postgresql][:config].key?(:port)
          port = custom_json[:postgresql][:config][:port]
        end

        perm_match = false
        group = client.security_groups.filter('group-name', POSTGRES_GROUP_NAME).first

        unless group
          $stdout.puts "Creating security group: #{POSTGRES_GROUP_NAME} in #{client.regions.first.name}"
          group = client.security_groups.create(POSTGRES_GROUP_NAME)
        else
          group.ingress_ip_permissions.each do |ipperm|
            if ipperm.protocol == :tcp && ipperm.port_range == port..port
              perm_match = true
            else
              ipperm.revoke
            end
          end
        end

        group.authorize_ingress(:tcp, port) unless perm_match
      end

      def fetch_account(options = {})
        return account if account && !options[:force]

        configure_iam_client

        self.account = iam_client.get_user

        self.account_id = nil

        account[:user][:arn].match(/.*:.*:.*:.*:([0-9]+)/) do |m|
          self.account_id = m[1]
        end

        fail StandardError.new('Failed to determine account ID from user info (it was me not you!)!') unless
          account_id

        account
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

      def fetch_roles
        configure_iam_client

        service = 'aws-opsworks-service-role'
        instance = 'aws-opsworks-ec2-role'

        iam_client.list_roles[:roles].each do |role|
          config[:instance_arn] = role[:arn] if role[:role_name] == instance && !config.key?(:instance_arn)
          config[:service_arn] = role[:arn] if role[:role_name] == service && !config.key?(:service_arn)
        end
      end

      def roles_configured?
        fetch_roles
        service_role_configured? && instance_role_configured?
      end

      def service_role_configured?
        fetch_roles
        config.key?(:service_arn) && config[:service_arn] != nil
      end

      def instance_role_configured?
        fetch_roles
        config.key?(:instance_arn) && config[:instance_arn] != nil
      end

      def configure_roles
         configure_service_roles
         configure_instance_roles
      end

      def configure_instance_roles
        return true if instance_role_configured?
        fetch_account

        instance_role = "%7B%22Version%22%3A%222008-10-17%22%2C%22Statement%22%3A%5B%7B%22Sid%22%3A%22%22%2C%22Effect%22%3A%22Allow%22%2C%22Principal%22%3A%7B%22Service%22%3A%22ec2.amazonaws.com%22%7D%2C%22Action%22%3A%22sts%3AAssumeRole%22%7D%5D%7D"
        instance_resource = 'role/aws-opsworks-ec2-role'
        instance_role_arn = "arn:aws:iam::#{account_id}:#{instance_resource}"
      end

      def configure_service_roles
        return true if service_role_configured?
        fetch_account

        opsworks_role =  "%7B%22Version%22%3A%222008-10-17%22%2C%22Statement%22%3A%5B%7B%22Sid%22%3A%22%22%2C%22Effect%22%3A%22Allow%22%2C%22Principal%22%3A%7B%22Service%22%3A%22opsworks.amazonaws.com%22%7D%2C%22Action%22%3A%22sts%3AAssumeRole%22%7D%5D%7D"
        opsworks_resource = 'role/aws-opsworks-service-role'
        opsworks_role_arn = "arn:aws:iam::#{account_id}:#{opsworks_resource}"
      end

      def create_role(config)
        $stderr.puts config.to_json
      end

      def create_app(config)
        $stderr.puts config.to_json
      end

      def valid_instances?(args)
        args = [args] unless args.is_a?(Array)

        return false if args.length == 0

        fetch_instance

        inst_names = instances.map do |inst|
          # if requested is stop, its definitely invalid.
          return false if args.index(inst[:hostname]) != nil &&
            inst[:status] == 'stopped'

          inst[:hostname]
        end

        # if a requested is not in the list, then its an invalid list.
        args.each do |arg|
          if inst_names.index(arg) == nil
            return false
          end
        end

        true
      end

      def select_instances(args)
        fetch_instance
        return instances_list unless args

        args = [args] unless args.is_a?(Array)
        return nil if args.length == 0

        self.instances = instance_list.select do |inst|
          args.index(inst[:hostname]) != nil
        end
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