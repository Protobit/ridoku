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

      load_environment

      case sub_command
      when 'list', nil
        list
      when 'set', 'add', 'update'
        add
      when 'delete'
        delete
      when 'remove'
        remove
      else
        print_cron_help
      end
    end

    protected

    def load_environment
      Base.fetch_stack
      Base.fetch_instance('workers')

      @default_instance = Base.instances.first[:hostname]
      self.cron = (Base.custom_json['deploy'][Base.config[:app].downcase]['cron'] ||= {})
    end

    def print_cron_help
      $stderr.puts <<-EOF
Command: cron

List/Modify the current app's associated cron.
  cron[:list]   lists the cron jobs associated with an application.
  cron:add      cron job, e.g., runner:scripts/runme.rb hour:0 minute:0
  cron:delete   delete this specific cron job
  cron:remove   removes a cron from the list (run after a delete and push)
  cron:push     update running cron jobs

Columns             Value (default: *)    Label
  M   Minute        0-59                  minute
  H   Hour          0-23                  hour
  DM  Day of Month  0-30                  day_of_month
  MO  Month         0-11                  month
  DW  Day of Week   0-6                   day_of_week

All cron jobs are run on the Workers layer or the AssetMaster on the
Rails Application layer if one is not set, unless otherwise specified.

Example 'cron:list' output:
Type     Scripts                M    H    DM   MO   DW
runner   scripts/runme.rb       0    0    *    *    *

The above list output indicates a DelayedJob cron and two separate
delayed_job processes.  One processing 'mail'; the other processing 'sms'.

examples:
  $ cron
  No cron specified!
  $ cron:add type:runner path:scripts/runme.rb hour:0 minute:0
  $ cron:add type:runner path:scripts/runme_also.rb minute:*/5 instance:mukujara
  $ cron:list
  Type     Scripts                M    H    DM   MO   DW  Instance
  runner   scripts/runme.rb       0    0    *    *    *   oiwa
  runner   scripts/runme_also.rb  */5  *    *    *    *   mukujara
  $ cron:delete scrips/runme_also.rb
  Type     Scripts                M    H    DM   MO   DW
  runner   scripts/runme.rb       0    0    *    *    *   oiwa
  delete   scripts/runme_also.rb  -    -    -    -    -   mukujara
EOF
    end

    def list
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
          day_of_week: 'DW',
          instance: 'Instance'
        }

        offset = {}

        self.cron.each do |cr|
          columns.keys.each do |key|
            skey = key.to_s
            cr[skey] = '*' unless cr.key?(skey)
            val = cr[skey].length
            offset[key] = val if cr.key?(skey) && val > (offset[key] || 0)
          end
        end

        columns.keys.each do |key|
          offset[key] = columns[key].length if
            columns[key].length > (offset[key] || 0)
        end

        $stdout.puts $stdout.colorize(line(offset, columns), :bold)
        self.cron.each { |cr| $stdout.puts line(offset, cr, columns.keys) }
      end
    rescue =>e
      puts e.backtrace
      puts e
    end

    def add

      croninfo = {}
      cronindex = nil

      ARGV.each do |cron|
        info = cron.split(':',2)
        croninfo[info[0].to_s] = info[1]
        cronindex = get_path_index(info[1]) if info[0] == 'path'
      end

      croninfo['instance'] = @default_instance unless croninfo.key?('instance')

      if cronindex.nil?
        self.cron << croninfo
      else
        self.cron[cronindex] = croninfo
      end

      list
      Base.save_stack
    end

    def delete
      return print_cron_help unless ARGV.length > 0
      cronindex = get_path_index(ARGV.first)

      if cronindex.nil?
        $stdout.puts $stdout.colorize(
          'Unable to find the specified script path in the cron list.', :red)
        return list
      end

      cr = self.cron[cronindex]
      cr['type'] = 'delete'
      cr['minute'] = '-'
      cr['hour'] = '-'
      cr['day_of_month'] = '-'
      cr['month'] = '-'
      cr['day_of_week'] = '-'
      
      list
      Base.save_stack
    end

    def remove
      return print_cron_help unless ARGV.length > 0
      cronindex = get_path_index(ARGV.first)

      if cronindex.nil?
        $stdout.puts $stdout.colorize(
          'Unable to find the specified script path in the cron list.', :red)
        return list
      end

      self.cron.delete_at(cronindex)

      list
      Base.save_stack
    end

    protected

    def get_path_index(path)
      cron.each_with_index do |cr, idx|
        return idx if cr['path'] == path
      end

      return nil
    end

    def line(offset, columns, keys = nil)
      keys ||= columns.keys
      output = ''

      keys.each do |key|
        skey = key.to_s
        content = columns[key] || columns[skey]
        if skey == 'type'
          case content
          when 'delete'
            output += $stdout.colorize(content, :red)
          when 'runner'
            output += $stdout.colorize(content, :green)
          else
            output += $stdout.colorize(content, :yellow)
          end
        else
          output += content
        end
        output += ' '*(offset[key] - content.length + 2)
      end

      output
    end
  end
end