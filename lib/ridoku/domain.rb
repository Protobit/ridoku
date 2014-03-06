#
# Command: domain
#

require 'ridoku/base'
require 'json'

module Ridoku
  register :domain

  class Domain < Base
    attr_accessor :domains

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
      when 'push'
        push_update
      else
        print_domain_help
      end
    end

    protected

    def load_environment
      Base.fetch_app
      self.domains = (Base.app[:domains] ||= [])
    end

    def print_domain_help
      $stderr.puts <<-EOF
Command: domain

List/Modify the current app's associated domains.
   domain[:list]   lists the key value pairs
   domain:add      domain, e.g., http://app.example.com
   domain:delete   domain or index
   domain:push     push updated domains to the server

examples:
  $ domain
  No domains specified!
  $ domain:add app.example.com
  $ domain:list
  Domains:
   0: app.example.com
  EOF
    end

    def list
      if domains.length == 0
        $stdout.puts 'No domains specified!'
      else
        $stdout.puts 'Domains:'
        domains.each_index do |idx|
          $stdout.puts "  #{$stdout.colorize(idx.to_s, :bold)}: #{domains[idx]}"
        end
      end
    end

    def add
      ARGV.each do |domain|
        if domains.index(domain) == nil
          domains << domain 
          $stdout.puts "Adding #{domain}."
        end
      end

      Base.save_app(:domains)
    end

    def delete
      ARGV.each do |domain|
        if domain.match(/^[0-9]+$/)
          value = domains.delete_at(domain.to_i)
        else
          value = domains.delete(domain)
        end
        $stdout.puts "Deleting domain: #{value}"
      end
      
      Base.save_app(:domains)
    end

    def push_update
      if domains.length == 0
        $stdout.puts 'No domains specified!'
        $stderr.puts 'Please specify at least 1 domain and try again.'
        return
      end

      Base.fetch_instance('rails-app')
      Base.fetch_app

      Base.instances.select! { |inst| inst[:status] == 'online' }
      instance_ids = Base.instances.map { |inst| inst[:instance_id] }

      $stdout.puts "Application:"
      $stdout.puts "  #{$stdout.colorize(Base.app[:name], :bold)}"
      $stdout.puts "Pushing domains:"

      domains.each_index do |idx|
        $stdout.puts "  #{$stdout.colorize(idx.to_s, :bold)}: #{domains[idx]}"
      end

      $stdout.puts "To #{Base.instances.length} instance(s):"

      Base.pretty_instances($stdout).each do |inst|
        $stdout.puts "  #{inst}"
      end

      $stdout.puts "Repository:"
      $stdout.puts "  #{$stdout.colorize(Base.app[:app_source][:url], :bold)}"\
        " @ #{$stdout.colorize(Base.app[:app_source][:revision], :bold)}"

      command = Base.deploy(Base.app[:app_id], instance_ids,
        Base.config[:comment])
      Base.run_command(command)
    end
  end
end