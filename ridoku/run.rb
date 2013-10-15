#
# Command: run
#

require "#{File.dirname(__FILE__)}/base.rb"

module Ridoku
  class Run < Base
    def run
      $stderr.puts '\'run\' method not implemented'
    end

    protected

    def print_run_help
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
  end
end