#
# Command: backup
#

require 'ridoku/base'

module Ridoku
  register :backup

  class Backup < Base
    attr_accessor :services

    def run(command = nil)
      command ||= Base.config[:command]
      command.shift
      sub_command = command.shift

      case sub_command
      when 'stack'
        action = command.shift
        if action.nil? || action == 'store'
          backup_stack(ARGV)
        elsif action == 'restore'
          restore_stack(ARGV)
        else
          print_backup_help
        end
      else
        print_backup_help
      end
    end

    protected

    def load_environment
      Base.fetch_stack
    end

    def print_backup_help
      $stderr.puts <<-EOF
Command: backup

List/Modify the current app's associated workers.
   backup[:help]          this page
   backup:stack[:store]           backup the stack's Custom JSON to a file
   backup:stack:restore   restore the stack's Custom JSON from a file
EOF
    end

    def backup_stack(args)
      IO.write(args.shift, JSON.generate(Base.custom_json))
    rescue => e
      $stderr.puts "#{e.class}: #{e.to_s}"
    end
  end
end