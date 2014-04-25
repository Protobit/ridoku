#
# Command: deploy
#

require 'ridoku/base'

module Ridoku
  register :deploy

  class Deploy < Base
    attr_accessor :app

    def run
      clist = Base.config[:command]
      command = clist.shift
      sub_command = clist.shift

      case sub_command
      when 'to', nil
        deploy
      when 'rollback'
        rollback
      when 'restart'
        restart
      when 'info'
        info
      else
        print_deploy_help
      end
    end

    protected

    def rollback
      Base.fetch_instance
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
      $stdout.puts "Rolling back on #{Base.instances.length} instance(s):"
      Base.pretty_instances($stdout).each do |inst|
        $stdout.puts "  #{inst}"
      end
      $stdout.puts "Repository:"
      $stdout.puts "  #{$stdout.colorize(Base.app[:app_source][:url], :bold)} " +
        "@ #{$stdout.colorize(Base.app[:app_source][:revision], :bold)}"

      command = Base.rollback(Base.app[:app_id], instance_ids,
        Base.config[:comment], {
          opsworks_custom_cookbooks: {
            recipes: [
              "workers::rollback"
            ]
          }
        }
      )

      Base.run_command(command)
    end

    def deploy
      custom_json = {}.tap do |json|
        json[:deploy] = {
          Base.config[:app] => {
            action: 'force_deploy'
          }
        } if Base.config[:force]

        json[:migrate] = true if Base.config[:migrate]
        json[:opsworks_custom_cookbooks] = {
          recipes: [
            "workers::deploy"
          ]
        }
      end

      if Base.config[:force]
        begin
          $stdout.puts 'Hold your seats: force deploying in... (Press CTRL-C to Stop)'
          5.times { |t| $stdout.print "#{$stdout.colorize(5-t, :red)} "; sleep 1 }
          $stdout.puts "\nSilence is acceptance..."
        rescue Interrupt
          $stdout.puts $stdout.colorize("\nCommand canceled", :green)
          exit 1
        end
      end

      $stdout.puts 'Database will be migrated.' if Base.config[:migrate]
      Base.standard_deploy(:all, custom_json)
    end

    def restart
      Base.fetch_app

      Base.config[:layers] = 'rails-app'
      custom_json = {}.tap do |json|
        json[Base.app[:name]] = {
          deploy: {
            application_type: 'rails'
          }
        }
      end

      $stdout.puts "Restarting application: #{Base.app[:name]}."
      Ridoku::Cook.cook_recipe('unicorn::force-restart', custom_json)
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
    deploy            deploy the given application to stack instances
      --layers/-l <layers,...>:
        used to specify which layers in the stack to deploy to if not
        specified, all online stack instances are deployed
      --practice/-p:
        print what would be done, but don't actually do it
    deploy:rollback   rollback the most recently deployed application.
        NOTE: This will not rollback environment, database, or domain changes.
              It will only rollback source code changes.  Configurations will
              remain the same.
    deploy:restart   Force Restart the unicorn servers (service will go down).

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