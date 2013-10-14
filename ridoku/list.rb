#
# Command: list
# Description: Used to list all stacks on an AWS OpsStack account.
#   The current selection is colorized green.
#

require "#{File.dirname(__FILE__)}/base.rb"

module Ridoku
  class List < Base
    def run
      stacks = Base.aws_client.describe_stacks
      stack_arr = stacks[:stacks].map do |stack|
        name = stack[:name]
        (name == Base.config[:app] && $stdio.colorize(name, :green)) || name
      end

      list = stack_arr.join(', ')
      $stdout.puts 'Application stacks on your account:'
      $stdout.puts " #{$stdout.colorize(list, :bold)}"
    end
  end
end