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
      when 'app'
        app(type || 'rails')
      else
        print_create_help
      end
    end

    protected

    def configure_from_cwd(opt)
      return unless File.exists?('.git')

      `git remote -v | grep fetch`.match(%r(origin\s*(git@[^\s]*).*)) do |m|
        opt[:type] = 'git'
        opt[:url] = m[1]
        $stdout.puts "Setting Git Application Source from environment:"
        $stdout.puts "Url: #{$stdout.colorize(m[1], :green)}"
      end
    end

    def print_create_help
      $stderr.puts <<-EOF
Command: create

List/Modify the current layer's package dependencies.
  create                      show this help
  create:app[:rails] <name>   create a new app on the --stack

Currently, if the stack does not exist for a particular app type, you
will have to create it manually.
  EOF
    end

    def app(type)
      Base.fetch_stack

      unless ARGV.length > 0
        $stderr.puts $stderr.colorize('App name not specified', :red)
        print_create_help
        exit 1
      end

      config = {
          type: type,
          name: ARGV[0],
          shortname: ARGV[0].downcase.gsub(%r([^a-z0-9]), '-')
      }

      config.tap do |opt| 
          opt[:domains] = Base.config[:domains] if Base.config.key?(:domains)
          opt[:app_source] = {}.tap do |as|
            configure_from_cwd(as)
            as[:ssh_key] = Base.config[:ssh_key] if Base.config.key?(:ssh_key)
          end
          opt[:attributes] = {}.tap do |atr|
            atr[:rails_env] = Base.config[:rails_env] if Base.config.key?(:rails_env)
          end
      end

      appconfig = RailsDefaults.new.defaults_with_wizard(:app, config)

      begin
        Base.create_app(appconfig)
      rescue ::ArgumentError => e
        $stderr.puts e.to_s
      end
    end

    def instance
      $stderr.puts 'Create instance not yet implemented.'
      $stderr.puts 'Create an instance for a given layer using OpsWorks Dashboard.'
    end
  end
end