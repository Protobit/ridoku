# Pull new requires from 'test/overrides' before anything else.
# Here's looking at you AWS.
$:.unshift File.join(File.dirname(__FILE__), 'overrides')

require 'stringio'

require 'ridoku'
require 'io-colorize'

def init_ridoku(config, modul)
  Ridoku::Base.load_config("test/configs/#{config}.config")
  Ridoku::Base.config[:command] = [modul]
end

def sub_command(*sub)
  Ridoku::Base.config[:command] << sub
  Ridoku::Base.config[:command].flatten!
end

module ColorizeHelper
  def colorize(input, args)
    input
  end
end

def capture_output
  out = StringIO.new
  err = StringIO.new
  out.extend(ColorizeHelper)
  err.extend(ColorizeHelper)
  $stdout = out
  $stderr = err
  yield
  return out, err
ensure
  $stdout = STDOUT
  $stderr = STDERR
end
