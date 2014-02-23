#
# Command: worker
#

require 'ridoku/base'

module Ridoku
  register :workers

  class Worker < Base
    attr_accessor :workers

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
        print_worker_help
      end
    end

    protected

    def load_environment
      Base.fetch_stack
      self.workers = (Base.custom_json['deploy'][Base.config[:app].downcase]['workers'] ||= {})
    end

    def print_worker_help
      $stderr.puts <<-EOF
    Command: worker

    List/Modify the current app's associated workers.
       worker[:list]   lists the worker type and separate process queues
       worker:add      worker, e.g., delayed_job:queue_name
       worker:delete   delete all keys associated with a worker

    Example 'worker:list' output:
       delayed_job: ["mail", "sms"]

    The above list output indicates a DelayedJob worker and two separate
    delayed_job processes.  One processing 'mail'; the other processing 'sms'.

    examples:
      $ worker
      No workers specified!
      $ worker:add delayed_job:mail
      $ worker:add delayed_job:sms
      $ worker:list
      Workers for MyCurrentApp:
       delayed_job: ["mail", "sms"]
      $ worker:delete delayed_job
      No workers specified!
      EOF
    end

    def list
      if workers.length == 0
        $stdout.puts 'No workers specified!'
      else
        $stdout.puts "Workers for #{Base.config[:app]}:"
        workers.each do |type, queues|
          $stdout.puts "  #{$stdout.colorize(type.to_s, :bold)}: #{queues.to_s}"
        end
      end
    end

    def add
      ARGV.each do |worker|
        new_workers = worker.split(':')
        workers[new_workers[0]] ||= []
        workers[new_workers[0]] << new_workers[1]
        workers[new_workers[0]].flatten!
        $stdout.puts "Adding #{worker}."
      end

      list
      Base.save_stack
    end

    def delete
      ARGV.each do |worker|
        workers.delete(worker)
        $stdout.puts "Deleting worker: #{worker}"
      end

      list
      Base.save_stack
    end
  end
end