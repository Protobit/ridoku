#
# Command: log
#

require 'ridoku/base'

module Ridoku
  register :log

  class Log < Base
    attr_accessor :environment
    
    def run      
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil

      case sub_command
      when 'unicorn', nil
        unicorn_log
      when 'nginx'
        nginx_log
      when 'all'
        all_logs
      else
        print_log_help
      end
    end

    protected

    def unicorn_log_command
      lines = "#{Base.config[:lines] || 250}"
      dir = "/srv/www/#{Base.config[:app]}/shared/log"
      "for f in #{dir}/*.log; do echo "\
      "#{$stdout.colorize("Log #{lines}: $f; "\
      "echo #{'=' * 80}", [:bold])};"\
      "tail -#{lines} $f; echo; done"
    end

    def line_break(title)
      "#{'=' * 80}\n==== #{title}\n#{'=' * 80}\n"
    end

    def unicorn_log
      $stdout.puts $stdout.colorize(line_break('Unicorn Logs'), [:bold, :green])
      system(Ridoku::Run.command(unicorn_log_command, false))
    end

    def nginx_log
      $stdout.puts $stdout.colorize(line_break('Nginx Logs'), [:bold, :green])
      system(Ridoku::Run.command('tail -1000 /var/log/nginx/error.log'))
    end

    def all_logs
      nginx_log
      unicorn_log
    end


    def print_log_help
      $stderr.puts <<-EOF
Command: log

Log the specified command on an instance:
  log[:unicorn] print unicorn logs for the specified app and instance
  log:nginx     print nginx logs for the specified app and instance
  log:all       print all logs for specified instance and app to commandline

examples:
  $ ridoku log --mukujara
    
    EOF
    end
  end
end