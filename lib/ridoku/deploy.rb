#
# Command: deploy
#

require 'ridoku/base'

module Ridoku
  register :deploy

  class Deploy < Base
    attr_accessor :app

    def run
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil

      case sub_command
      when 'to', nil
        deploy
      when 'info'
        info
      else
        print_deploy_help
      end
    end

    protected

    def deploy
      Base.fetch_instance('rails-app')
      Base.fetch_app

      Base.instances.select! { |inst| inst[:status] == 'online' }
      instance_ids = Base.instances.map { |inst| inst[:instance_id] }

      # :app_source => {
      #   :type => "git",
      #   :url => "git@github.com:Protobit/Survly.git",
      #   :ssh_key => "*****FILTERED*****",
      #   :revision => "opsworks-staging"
      # }

      $stdout.puts "Application:"
      $stdout.puts "  #{$stdout.colorize(Base.app[:name], :bold)}"
      $stdout.puts "Deploying to #{Base.instances.length} instance(s):"
      Base.pretty_instances($stdout).each do |inst|
        $stdout.puts "  #{inst}"
      end
      $stdout.puts "Repository:"
      $stdout.puts "  #{$stdout.colorize(Base.app[:app_source][:url], :bold)} " +
        "@ #{$stdout.colorize(Base.app[:app_source][:revision], :bold)}"

      deployment = {
        app_id: Base.app[:app_id],
        instance_ids: instance_ids,
        command: {
          name: 'deploy'
        }
      }

      deployment.tap do |dep|
        dep[:comment] = Base.config[:comment] if Base.config.key?(:comment)
      end

      Base.deploy(deployment)
    end

    def info
      Base.fetch_instance('rails-app') unless Base.instances

      Base.instances = Base.instances.select do |inst|
         inst[:status] == 'online'
      end

      $stdout.puts 'Instances which will be deployed:'
      $stdout.puts Base.pretty_instances($stdout)
    end

    def print_deploy_help      
      $stderr.puts <<-EOF
  Command: deploy

  Deploy the specified application:
    deploy         deploy the given application to stack instances
      --instances: used to specify which instances in the stack to deploy to
                   if not specified, all active stack instances are used
      --practice   print what would be done, but don't actually do it

  examples:
    $ deploy
    Application:
      test-app
    Deploying to 2 instances:
      mukujara, hinoenma
    Using git repository:
      git@github.com:ridoku/example-app.git @ master
    EOF
    end
  end
end