#
# Command: service
#

require 'ridoku/base'


module Ridoku
  module Services
    @service_list = []
    def self.add_service(serv)
      @service_list << serv.to_s
    end

    def self.list
      @service_list
    end
  end
end

require_rel 'services/'

module Ridoku
  class Service < Base
    attr_accessor :services

    # "services":[{
    #   "name": "rabbitmq",
    #   "layers": [
    #     "worker"
    #   ]
    # },...]

    # Service name should be the same used to define configurations, ideally.

    def run(command = nil)
      command ||= Base.config[:command]
      command.shift
      sub_command = command.shift

      environment = load_environment
      case sub_command
      when 'list', nil
        list
      when 'set', 'add'
        add
      when 'delete', 'remove', 'rm'
        delete
      when 'config'
        config(ARGV)
      else
        print_service_help
      end
    end

    protected

    def load_environment
      Base.fetch_stack
      self.services = (Base.custom_json['services'] ||= {})
    end

    def print_service_help
      $stderr.puts <<-EOF
Command: service

List/Modify the current app's associated workers.
   service[:list]   lists the services and what layer they are assigned
   service:add      service:layer, e.g., rabbitmq:workers
   service:delete   delete service information from stack and layer
   service:config   service:list for description of service configuration layer

Example 'service:list' output:
  Services for MyStack:
    [layer] service 

examples:
  $ services
  No services specified!
  $ services:add rabbitmq:workers
  $ services:add nagios:workers # not yet implemented
  $ services:list
  Services for MyStack:
   [layer] service
   [workers] rabbitmq
   [workers] nagios
  $ services:delete nagios
  Services for MyStack:
   [layer] service
   [workers] rabbitmq
  $ services:config rabbitmq:help
    ...
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

    def add
    end

    def delete
    end

    def config(argv)
      klass, cmd = argv.shift.split(/:/)

      if klass.nil?
        $stdout.puts 'Available services:'
        Ridoku::Services.list.each { |service| $stdout.puts " #{service}" }
        return
      end

      begin
        command = Ridoku::Services.const_get(
          klass.capitalize
        ).new
      rescue => e
        $stderr.puts "Invalid service:config command specified: #{klass}"
        puts e.to_s if Ridoku::Base.config[:debug]
        print_help
        exit 1
      end

      begin
        command.run cmd, argv
      rescue Ridoku::InvalidConfig => e
        $stderr.puts "#{e.error.to_s.capitalize} #{e.type.to_s} specified."
        $stderr.puts 'Use the `list` command to see relavent info.'
        print_help
        exit 1
      rescue Ridoku::NoSshAccess
        $stderr.puts 'Your user does not have access to ssh on the specified stack.'
        print_help
        exit 1
      rescue ArgumentError => e
        raise e if Ridoku::Base.config[:debug]
        $stderr.puts e.to_s
      end

    end
  end
end