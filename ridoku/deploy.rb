#
# Command: deploy
#

require "#{File.dirname(__FILE__)}/base.rb"

module Ridoku
  class Deploy < Base
    attr_accessor :app
    def run
      Base.fetch_stack

      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil

      case sub_command
      when 'to', nil
        deploy
      when 'info'
        info
      else
        print_deploy_help
        exit 1
      end
    end

    protected

    def deploy
      Base.fetch_instances('rails-app')
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
      $stdout.puts Base.pretty_instances($stdout)
      $stdout.puts "Repository:"
      $stdout.puts "#{$stdout.colorize(Base.app[:app_source][:url], :bold)} " +
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
      Base.fetch_instances('rails-app') unless Base.instances

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

  examples:
    $ deploy
    Application:
      test-app
    Deploying to 2 instances:
      mukujara, hinoenma
    Using git repository:
      git@github.com:ridoku/example-app.git @ master
    This may take a while...
    Successfully Deployed
    EOF
    end
  end
end