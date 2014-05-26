# encoding: utf-8

#
# Command: cron
#

# [:day, :hour, :minute, :month, :weekday, :path, :type, :action]

require 'ridoku/base'

module Ridoku
  register :cron

  class Cron < Base
    attr_accessor :cron

    def run
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil

      environment = load_environment

      case sub_command
      when 'list', nil
        list
      when 'set', 'add'
        add
      when 'delete', 'remove', 'rm'
        delete
      else
        print_cron_help
      end
    end

    protected

    def load_environment
      Base.fetch_stack
      self.cron = (Base.custom_json['deploy'][Base.config[:app].downcase]['cron'] ||= {})
    end

    def print_cron_help
      $stderr.puts <<-EOF
Command: cron

List/Modify the current app's associated cron.
  cron[:list]   lists the cron jobs associated with an application.
  cron:add      cron job, e.g., runner:scripts/runme.rb hour:0 minute:0
  cron:delete   delete this specific cron job

Columns             Value (default: *)
  M   Minute        0-59
  H   Hour          0-23
  DM  Day of Month  0-30
  MO  Month         0-11
  DW  Day of Week   0-6

Example 'cron:list' output:
Type     Scripts                M    H    DM   MO   DW
runner   scripts/runme.rb       0    0    *    *    *

The above list output indicates a DelayedJob cron and two separate
delayed_job processes.  One processing 'mail'; the other processing 'sms'.

examples:
  $ cron
  No cron specified!
  $ cron:add runner=scripts/runme.rb hour=0 minute=0
  $ cron:add runner=scripts/runme_also.rb minute=*/5
  $ cron:list
  Type     Scripts                M    H    DM   MO   DW
  runner   scripts/runme.rb       0    0    *    *    *
  runner   scripts/runme_also.rb  */5  *    *    *    *
  $ cron:delete runner=scripts/runme_also.rb
  Type     Scripts                M    H    DM   MO   DW
  runner   scripts/runme.rb       0    0    *    *    *
  delete   scripts/runme_also.rb  -    -    -    -    -
EOF
    end

    def list
      Base.fetch_stack
      if cron.length == 0
        $stdout.puts 'No cron jobs specified!'
      else

        columns = ['Type', 'Scripts', 'M', 'H', 'DM', 'MO', 'DW']
        offset = []

        cron.each do |type, queues|

        end
      end
    end

    def add
      ARGV.each do |cron|
      end

      list
      Base.save_stack
    end

    def delete
      ARGV.each do |cron|
        cron.delete(cron)
        $stdout.puts "Deleting cron: #{cron}"
      end

      list
      Base.save_stack
    end
  end
end