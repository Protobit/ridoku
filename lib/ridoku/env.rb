#
# Command: env
# Description: List/Modify the current apps configuration.
#  env - lists the key value pairs
#  env:set KEY:VALUE [...]
#  env:delete KEY
#

require 'ridoku/base'

module Ridoku
  class Env < Base
    attr_accessor :environment

    def run
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil

      environment = load_environment

      case sub_command
      when 'list', nil
        list
      when 'set', 'add'
        set
      when 'delete', 'remove', 'rm'
        delete
      else
        print_env_help
      end
    end

    protected

    def load_environment
      Base.fetch_stack

      self.environment =
        Base.custom_json['deploy'][Base.config[:app].downcase]['app_env']
    end

    def print_env_help
      $stderr.puts <<-EOF
    Command: env

    List/Modify the current app's environment.
       env        lists the key value pairs
       env:set    KEY:VALUE [...]
       env:delete KEY [...]

    examples:
      $ env
      Environment Empty!
      $ env:set AWS_ACCESS_KEY:'jas8dyfawenfi9f'
      $ env:set AWS_SECRET_KEY:'SJHDF3HSDOFJS4DFJ3E'
      $ env:delete AWS_SECRET_KEY
      $ env
      Environment:
        AWS_ACCESS_KEY: 'jas8dyfawenfi9f'
      EOF
    end

    def list
      if environment.keys.length == 0
        $stdout.puts 'Environment Empty!'
      else
        $stdout.puts 'Environment:'
        environment.each do |key, value|
          $stdout.puts "  #{$stdout.colorize(key, :bold)}: '#{value}'"
        end
      end
    end

    def set
      ARGV.each do |kvpair|
        kvpair.match(%r((^[^:]+):(.*))) do |m|
          key = m[1]
          value = m[2]

          update = environment.key?(key)
          environment[key] = value
          $stdout.puts "#{update && 'Updating' || 'Adding'}: #{key} as '#{value}'"
        end
      end

      Base.save_stack
    end

    def delete
      ARGV.each do |key|
        value = environment.delete(key)
        $stdout.puts "Deleting key: #{key}, '#{value}'"
      end
      
      Base.save_stack
    end
  end
end