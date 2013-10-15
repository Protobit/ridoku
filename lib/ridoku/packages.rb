#
# Command: packages
# Description: List/Modify the current apps configuration.
#  packages - lists the key value pairs
#  packages:add PACKAGE [...]
#  packages:delete KEY
#

require 'ridoku/base'

module Ridoku
  class Packages < Base

    def run
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil

      case sub_command
      when 'list', nil
        list
      when 'set', 'add'
        set
      when 'delete', 'remove', 'rm'
        delete
      else
        print_package_help
      end
    end

    protected

    def print_package_help
      $stderr.puts <<-EOF
  Command: packages

  List/Modify the current layer's package dependencies.
     packages        lists the key value pairs
     packages:set    PACKAGE [...]
     packages:delete PACKAGE [...]
      EOF
    end

    def list
      Base.fetch_layers(Base.config[:layer] || 'rails-app')

      if Base.layers.length == 0
        $stdout.puts 'No Layers Selected!'

      else
        max = 0
        Base.layers.each do |layer|
          short = $stdout.colorize(layer[:shortname], :bold)
          max = short.length if max < short.length
        end
        
        Base.layers.each do |layer|
          fmt = "%#{max}s"
          shortname = sprintf(fmt, $stdout.colorize(layer[:shortname], :bold))
          $stdout.puts "[#{shortname}] #{layer[:name]}: " +
            "#{$stdout.colorize('No Packages Selected', :red) if
              layer[:packages].length == 0}"
          layer[:packages].each do |pack|
            $stdout.puts "  #{$stdout.colorize(pack, :green)}"
          end
        end
      end
    end

    def set
      Base.fetch_layers(Base.config[:layer] || 'rails-app')

      ARGV.each do |package|
        # $stdout.puts "#{update && 'Updating' || 'Adding'}: #{key} as '#{value}'"
      end

      # Base.save_layer(layer, :packages)
    end

    def delete
      Base.fetch_layers(Base.config[:layer] || 'rails-app')

      ARGV.each do |package|
        # $stdout.puts "Deleting key: #{key}, '#{value}'"
      end
      
      # Base.save_layer(layer, :packages)
    end
  end
end