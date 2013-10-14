#
# Command: deploy
#

require "#{File.dirname(__FILE__)}/base.rb"

module Ridoku
  class Deploy < Base
    def deploy
      $stderr.puts '\'deploy\' method not implemented'
    end
  end
end