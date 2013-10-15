#
# Command: domain
#

require 'ridoku/base'

module Ridoku
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
      else
        print_domain_help
      end
    end

    protected

    def load_environment
      Base.fetch_app

      self.domains = Base.app[:domains]
    end

    def print_domain_help
      $stderr.puts <<-EOF
    Command: domain

    List/Modify the current app's associated domains.
       domain[:list]   lists the key value pairs
       domain:add      domain, e.g., http://app.example.com
       domain:delete   domain or index

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
  end
end