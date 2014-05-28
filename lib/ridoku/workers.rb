#
# Command: worker
#

require 'ridoku/base'

module Ridoku
  register :worker

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
      when 'push', 'reconfigure'
        reconfigure
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
   worker:push     reconfigure the worker server.
                   Updates environment and DB changes.

Example 'worker:list' output:
   delayed_job: ["mail", "sms"]

The above list output indicates a DelayedJob worker and two separate
delayed_job processes.  One processing 'mail'; the other processing 'sms'.

examples:
  $ worker
  No workers specified!
  $ worker:add delayed_job=mail
  $ worker:add delayed_job=sms
  $ worker:add sneakers=Workers::MailWorker
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

    def reconfigure
      if Base.config[:wait]
        $stdout.puts 'Disabling command wait (2 commands to issue)...' 
        Base.config[:wait] = false
      end

      Base.fetch_app

      cjson = {
        deploy: {
          Base.app[:shortname] => {
            application_type: 'rails'
          }
        }
      }

      begin
        $stdout.puts 'This operation will '\
          "#{$stdout.colorize('RESTART', :red)} (not soft reload) "\
          'your application workers.'
        sleep 2
        $stdout.puts 'Hold your seats: worker reconfigure and force restart in... (Press CTRL-C to Stop)'
        5.times { |t| $stdout.print "#{$stdout.colorize(5-t, :red)} "; sleep 1 }
        $stdout.puts "\nSilence is acceptance..."
      rescue Interrupt
        $stdout.puts $stdout.colorize("\nCommand canceled successfully!", :green)
        exit 1
      end

      Base.config[:layers] = ['workers']
      Ridoku::Cook.cook_recipe(['rails::configure', 'workers::configure'], cjson)
    end

    def add
      ARGV.each do |worker|
        new_workers = worker.split('=')
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