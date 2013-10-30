#
#

require 'ridoku/base'

module Ridoku
  class Create < Base

    def run
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil
      type = (command.length > 1 && command[2]) || nil

      case sub_command
      when 'stack'
        stack(type || 'rails')
      when 'app'
        app(type || 'rails')
      when 'instance'
        instance
      else
        print_create_help
      end
    end

    protected

    def print_create_help
      $stderr.puts <<-EOF
  Command: create

  List/Modify the current layer's package dependencies.
    create                      show this help
    create:stack[:rails] <name> create a full stack ('rails' only currently)
    create:app[:rails] <name>   create a new app on the --stack
    create:instance             create an instance on the --layer
  EOF
    end

    def stack(type)
      $stderr.puts 'Create Stack not yet implemented.'
      $stderr.puts 'Create a Rails stack using OpsWorks Dashboard.'
    end

    def app(type)
      Base.fetch_stack

      #TODO: Extract some of the extra information from the environment!
      # Git/Svn? Pull from the repo.
      # 

      config = {
          type: type,
          name: ARGV[0],
          shortname: ARGV[0].downcase.gsub(%r([^a-z0-9]), '-')
      }

      config.tap do |opt| 
          opt[:domains] = Base.config[:domains] if Base.config.key?(:domains)
          opt[:app_source] = {}.tap do |as|
            as[:ssh_key] = Base.config[:ssh_key] if Base.config.key?(:ssh_key)
          end
          opt[:attributes] = {}.tap do |atr|
            atr[:rails_env] = Base.config[:rails_env] if Base.config.key?(:rails_env)
          end
      end

      appconfig = RailsDefaults.new.defaults_with_wizard(:app, config)

      Base.create_app(config)
    end

    def instance
      $stderr.puts 'Create instance not yet implemented.'
      $stderr.puts 'Create an instance for a given layer using OpsWorks Dashboard.'
    end
  end
end