#
# Base Ridoku class for running commands

require 'aws'
require 'active_support/inflector'
require 'securerandom'
require 'restclient'

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

        (self.config ||= {}).tap do |default|
          default[:wait] = true
        end
      end

      def save_config(path, limit = [:app, :stack, :ssh_key, :local_init,
        :shell_user, :service_arn, :instance_arn, :backup_bucket])
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

        fail InvalidConfig.new(:stack, :none) unless stack_name ||
          !options[:force]

        self.stack_list = aws_client.describe_stacks[:stacks]
        self.stack = nil
        
        stack_list.each do |stck|
          self.stack = stck if stack_name == stck[:name]
        end

        fail InvalidConfig.new(:stack, :invalid) if !stack &&
          !options[:force]

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

        app_list.each do |sapp|
          self.app = sapp if app_name == sapp[:name]
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

      def get_layer_ids(shortname)
        fetch_stack
        layers = aws_client.describe_layers(stack_id: stack[:stack_id])[:layers]
        layers.select { |l| l[:shortname] == shortname }
          .map { |l| l[:layer_id] }
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

      def instance_by_id(id)
        fetch_instance
        instance_list.select { |is| is[:instance_id] == id }.first
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

      def get_instances_for_layer(layer)
        layer_ids = get_layer_ids(layer)
        instances = aws_client
          .describe_instances(stack_id: stack[:stack_id])[:instances]
        ret = []
        layer_ids.each do |id|
          instances.each do |inst|
            ret << inst if inst[:layer_ids].include?(id)
          end
        end
        ret
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

        if custom_json.key?('postgresql') &&
          custom_json['postgresql'].key?('config')
          custom_json['postgresql']['config'].key?('port')
          port = custom_json['postgresql']['config']['port']
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

      def create_role(conf)
        if config[:practice]
          puts conf.to_s
        else
          iam_client.create_role(conf)
        end
      end

      def create_app(conf)
        conf[:stack_id] = stack[:stack_id]

        # Ensure key exists
        key_file = conf[:app_source][:ssh_key]
        
        fail ArgumentError.new('Key file doesn\'t exist.') unless
          File.exists?(key_file)

        File.open(key_file, 'r') { |f| conf[:app_source][:ssh_key] = f.read }

        # Config[:attributes] must be a hash of <string,string> type.
        conf[:attributes].tap do |opt|
          opt.keys.each do |k|
            opt[k.to_s.camelize] = opt.delete(k).to_s unless k.is_a?(String)
          end
        end

        # Ensure attribute 'rails_env' is specified
        fail ArgumentError.new('attribute:rails_env must be specified.') unless
          conf[:attributes]['RailsEnv'].length > 0

        if config[:practice]
          $stdout.puts conf.to_s
        else
          aws_client.create_app(conf)
          initialize_app_environment(conf)
        end
      end

      def initialize_app_environment(conf)
        fetch_stack
        fetch_layer
        fetch_instance

        app_layer = layer_list.select do |lyr|
          lyr[:shortname] == 'rails-app'
        end.first

        db_layer = layer_list.select do |lyr|
          lyr[:shortname] == 'postgresql'
        end.first

        deploy_info = custom_json['deploy']

        app = conf[:shortname]

        instance = instances.select do |inst|
          inst[:status] == 'online' &&
            inst[:layer_ids].index(app_layer[:layer_id]) != nil
        end.first

        db_instance = instances.select do |inst|
          inst[:layer_ids].index(db_layer[:layer_id]) != nil
        end.first

        dbase_info = {
          database: app,
          username: SecureRandom.hex(12),
          user_password: SecureRandom.hex(12)
        }

        ((custom_json['postgresql'] ||= {})['databases'] ||= []) << dbase_info

        deploy_info[app] = {
          auto_assets_precompile_on_deploy: true,
          assetmaster: instance[:hostname],
          app_env: {
            'RAILS_ENV' => conf[:attributes]['RailsEnv']
          },
          database: {
            adapter: 'postgresql',
            username: dbase_info[:username],
            database: dbase_info[:database],
            host: db_instance[:public_ip],
            password: dbase_info[:user_password],
            port: custom_json['postgresql']['config']['port']
          }
        }

        save_stack

        # Update add our changes to the database.
        run_command({
          instance_ids: [db_instance[:instance_id]],
          command: {
            name: 'execute_recipes',
            args: { 'recipes' => 'postgresql::create_databases' }
          }
        })
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
          inststr << io.colorize(val, 
            [:bold, inst[:status] == 'online' ? :green : :red])
        end

        inststr
      end

      def run_command(deployment)
        fetch_stack
        fetch_app

        deployment[:stack_id] = stack[:stack_id]

        if config[:practice]
          $stdout.puts "Would run command: #{deployment[:command][:name]}"
          $stdout.puts 'On instances:'
          instances.each do |inst|
            next unless
              deployment[:instance_ids].index(inst[:instance_id]) != nil

            $stdout.puts "  #{inst[:hostname]}: #{$stdout.colorize(
              inst[:status], inst[:status] == 'online' ? :green : :red)}"

          end

          if deployment.key?(:custom_json)
            $stdout.puts 'With custom_json:'
            $stdout.puts JSON.pretty_generate(deployment[:custom_json])
          end
        else
          if deployment.key?(:custom_json)
            deployment[:custom_json] = JSON.generate(deployment[:custom_json])
          end

          depid = aws_client.create_deployment(deployment)[:deployment_id]

          $stdout.puts $stdout.colorize('Command Sent', :green) if
            config[:verbose]

          monitor_deployment(depid) if config[:wait]
        end
      end
      
      def extract_instance_ids
        Base.fetch_instance(Base.config[:layers] || :all)

        names = Base.config[:instances] || []
        instances = Base.instances.select do |inst|
          if names.length > 0
            names.index(inst[:hostname]) != nil && inst[:status] != 'offline'
          else
            inst[:status] == 'online'
          end
        end

        instances.map do |inst|
          inst[:instance_id]
        end
      end

      def base_command(app_id, instance_ids, comment)
        fail ArgumentError.new('[ERROR] No instances selected.') if
          !instance_ids.is_a?(Array) || instance_ids.empty?

        {}.tap do |cmd|
          cmd[:instance_ids] = instance_ids
          cmd[:app_id] = app_id if app_id
          cmd[:comment] = comment if comment
        end
      end

      def update_cookbooks(instance_ids)
        command = Base.base_command(nil, instance_ids,
          Base.config[:comment])
        command[:command] = { name: 'update_custom_cookbooks' }
        command
      end

      def execute_recipes(app_id, instance_ids, comment, recipes,
        custom_json = nil)
        base_command(app_id, instance_ids, comment).tap do |cmd|
          cmd[:command] = {
            name: 'execute_recipes',
            args: { 'recipes' => [recipes].flatten }
          }
          cmd[:custom_json] = custom_json if custom_json
        end
      end

      def deploy(app_id, instance_ids, comment, custom_json = nil)
        base_command(app_id, instance_ids, comment).tap do |cmd|
          cmd[:command] = {
            name: 'deploy'
          }
          cmd[:custom_json] = custom_json if custom_json
        end
      end

      def rollback(app_id, instance_ids, comment, custom_json = nil)
        dep = deploy(app_id, instance_ids, comment, custom_json)
        dep[:command] = { name: 'rollback' }

        dep
      end

      def standard_deploy(layer = :all, custom_json = nil)
        fetch_instance(layer)
        fetch_app

        instances.select! { |inst| inst[:status] == 'online' }
        instance_ids = instances.map { |inst| inst[:instance_id] }

        unless config[:quiet]
          $stdout.puts "Application:"
          $stdout.puts "  #{$stdout.colorize(app[:name], :bold)}"

          $stdout.puts "#{instances.length} instance(s):"

          pretty_instances($stdout).each do |inst|
            $stdout.puts "  #{inst}"
          end

          $stdout.puts "Repository:"
          $stdout.puts "  #{$stdout.colorize(app[:app_source][:url], :bold)}"\
            " @ #{$stdout.colorize(app[:app_source][:revision], :bold)}"
        end

        run_command(deploy(app[:app_id], instance_ids, config[:comment],
          custom_json))
      end

      def color_code_logs(logs)
        $stderr.puts(logs.gsub(%r((?<color>\[[0-9]{1,2}m)),"\e\\k<color>"))
      end

      def monitor_deployment(dep_ids)
        cmds = aws_client.describe_commands(deployment_id: dep_ids)

        commands = cmds[:commands].map do |cmd|
          { command: cmd, instance: instance_by_id(cmd[:instance_id]) }
        end

        $stdout.puts "Command issued to #{commands.length} instances:"
        commands.each do |cmd|
          $stdout.puts "  #{$stdout.colorize(cmd[:instance][:hostname], 
            :green)}"
        end

        # Iterate a reasonable number of times... 100*5 => 500 seconds
        20.times do |time|
          cmds = aws_client.describe_commands(deployment_id: dep_ids)

          success = cmds[:commands].select do |cmd|
            cmd[:status] == 'successful'
          end

          # Show we are still thinking...
          case time % 4
          when 0
            print "\\\r"
          when 1
            print "|\r"
          when 2
            print "/\r"
          when 3
            print "-\r"
          end

          if cmds.length == success.length
            $stdout.puts 'Command executed successfully.'
            return
          end

          # Collect the non-[running,pending,successful] command entries
          not_ok = cmds[:commands].select do |cmd|
            ['running', 'pending', 'successful'].index(cmd[:status]) == nil
          end.map do |cmd|
            { 
              command: cmd,
              instance: instance_by_id(cmd[:instance_id])
            }
          end

          # Print each one that has failed.
          not_ok.each do |item|
            $stderr.puts "#{item[:instance][:hostname]}"
            $stderr.puts " Status: " +
              $stderr.colorize(item[:command][:status], :red)
            $stderr.puts " Url: " + item[:command][:log_url]
            color_code_logs(RestClient.get(item[:command][:log_url]))
            exit 1
          end

          sleep 5
        end
      end
    end
  end
end

BYTE_UNITS2 =[[1073741824, "GB"], [1048576, "MB"], [1024, "KB"], [0,
"B"]]

def nice_bytes(n)
  unit = BYTE_UNITS2.detect{ |u| n > u[0] }
  "#{n/unit[0]} #{unit[1]}"
end