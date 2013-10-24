#
#

require 'ridoku/base'

module Ridoku
  class Create < Base

    def run
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil

      case sub_command
      when 'stack'
        stack
      when 'app'
        app
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
     create                show this help
     create:stack[:rails]  create a full stack ('rails' only currently)
     create:app            create a new app on the --stack
     create:instance       create an instance on the --layer
  EOF
    end

    def stack
      $stderr.puts 'Create Stack not yet implemented.'
      $stderr.puts 'Create a Rails stack using OpsWorks Dashboard.'
    end

    def app
    end

    def instance
      $stderr.puts 'Create instance not yet implemented.'
      $stderr.puts 'Create an instance for a given layer using OpsWorks Dashboard.'
    end
  end
end