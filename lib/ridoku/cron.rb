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

Columns             Value (default: *)    Label
  M   Minute        0-59                  minute
  H   Hour          0-23                  hour
  DM  Day of Month  0-30                  day_of_month
  MO  Month         0-11                  month
  DW  Day of Week   0-6                   day_of_week

Example 'cron:list' output:
Type     Scripts                M    H    DM   MO   DW
runner   scripts/runme.rb       0    0    *    *    *

The above list output indicates a DelayedJob cron and two separate
delayed_job processes.  One processing 'mail'; the other processing 'sms'.

examples:
  $ cron
  No cron specified!
  $ cron:add type:runner path:scripts/runme.rb hour:0 minute:0
  $ cron:add type:runner path:scripts/runme_also.rb minute:*/5
  $ cron:list
  Type     Scripts                M    H    DM   MO   DW
  runner   scripts/runme.rb       0    0    *    *    *
  runner   scripts/runme_also.rb  */5  *    *    *    *
  $ cron:delete path:scrips/runme_also.rb
  Type     Scripts                M    H    DM   MO   DW
  runner   scripts/runme.rb       0    0    *    *    *
  delete   scripts/runme_also.rb  -    -    -    -    -
EOF
    end

    def list
      load_environment

      if cron.length == 0
        $stdout.puts 'No cron jobs specified!'
      else

        columns = {
          type: 'Type',
          path: 'Scripts',
          minute: 'M',
          hour: 'H',
          day_of_month: 'DM',
          month: 'MO',
          day_of_week: 'DW'
        }

        offset = {}

        cron.each do |cronjob|
          columns.keys.each do |key|
            cronjob[key.to_s] = '*' unless cronjob.key?(key.to_s)
            offset[key] = cronjob[key.to_s].length + 2 if cronjob.key?(key.to_s) &&
              cronjob[key.to_s].length + 2 > (offset[key] || 0)
          end
        end

        columns.keys.each do |key|
          offset[key] = columns[key].length if
            columns[key].length > (offset[key] || 0)
        end

        print_line(offset, columns)
        cron.each { |cr| print_line(offset, cr, columns.keys) }
      end
    rescue =>e
      puts e.backtrace
      puts e
    end

    def add
      croninfo = {}
      cronindex = 0

      ARGV.each do |cron|
        info = cron.split(':')
        croninfo[info[0].to_sym] = info[1]
        cronindex = get_path_index(info[1])
      end

      puts croninfo
      puts cronindex

      # list
      # Base.save_stack
    end

    def delete
      return print_cron_help unless ARGV.length > 0
      cronindex = get_path_index(ARGV.first)

      puts cron[cronindex] unless cronindex.nil?
      puts cronindex
      # list
      # Base.save_stack
    end

    protected

    def get_path_index(path)
      cron.each_with_index do |cr, idx|
        return idx if cr[:path] == path
      end

      return nil
    end

    def load_environment
      Base.fetch_stack
      self.cron = (Base.custom_json['deploy'][Base.config[:app].downcase]['cron'] ||= {})
    end

    def print_line(offset, columns, keys = nil)
      keys ||= columns.keys

      keys.each do |key|
        skey = key.to_s
        content = columns[key] || columns[skey]
        $stdout.print content
        $stdout.print ' '*(offset[key] - content.length)
      end

      $stdout.puts
    end
  end
end