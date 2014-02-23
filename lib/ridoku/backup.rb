#
# Command: backup
#

require 'ridoku/base'

module Ridoku
  class Backup < Base
    attr_accessor :services

    def run(command = nil)
      command ||= Base.config[:command]
      command.shift
      sub_command = command.shift

      case sub_command
      when 'stack'
        backup_stack ARGV
      when 'app'
        backup_stack ARGV
      else
        print_backup_help
      end
    end

    protected

    def load_environment
      Base.fetch_stack
      self.services = (Base.custom_json['services'] ||= {})
    end

    def print_backup_help
      $stderr.puts <<-EOF
Command: backup

List/Modify the current app's associated workers.
   backup[:help]  this page
   backup
EOF
    end

    def list
      if services.length == 0
        $stdout.puts 'No services specified!'
      else
        $stdout.puts "Services for #{$stdout.colorize(Base.config[:stack], [:bold, :green])}:"
        services.each do |service|
          if service['layers'].is_a?(Array)
            $stdout.puts "  [#{$stdout.colorize(service['layers'].join(','), :bold)}] #{service['name']}"
          else
            $stdout.puts "  [#{$stdout.colorize('No Layers Specified', [:bold, :red])}] #{service['name']}"
          end
        end
      end
    end
  end
end