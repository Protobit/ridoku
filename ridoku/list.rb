#
# Command: list
# Description: Used to list all stacks on an AWS OpsStack account.
#   The current selection is colorized green.
#

require "#{File.dirname(__FILE__)}/base.rb"

module Ridoku
  class List < Base    
    def run
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil
    
      case sub_command
      when nil
        return apps if Base.config[:stack]
        stacks

      when 'stacks'
        stacks

      when 'apps'
        apps

      when 'layers'
        layers

      when 'config'
        config

      else
        print_list_help
      end
    end

    protected

    def print_list_help
      $stderr.puts <<-EOF
    Command: list

    List/Modify the current app's database configuration.
       list        lists stacks or apps if stack is specified
       list:config lists current configuration information (app, stack, etc)
       list:stacks lists stacks by name
       list:apps   lists apps if stack is specified
       list:apps   lists layers if stack is specified
      EOF
    end

    def config
      config = [
        'Current:',
        "  #{$stdout.colorize('Stack', :bold)}: #{Base.config[:stack]}",
        "  #{$stdout.colorize('App', :bold)}: #{Base.config[:app]}"
      ]
      $stdout.puts config
    end

    def stacks
      stacks = Base.aws_client.describe_stacks
      stack_arr = stacks[:stacks].map do |stack|
        name = stack[:name]
        (name == Base.config[:stack] && $stdout.colorize(name, :green)) || name
      end

      list = stack_arr.join(', ')
      $stdout.puts 'Application stacks on your account:'
      $stdout.puts " #{$stdout.colorize(list, :bold)}"
    end

    def apps
      Base.fetch_stack

      apps = Base.aws_client.describe_apps(stack_id: Base.stack[:stack_id])
      app_arr = apps[:apps].map do |app|
        name = app[:name]
        (name == Base.config[:app] && $stdout.colorize(name, :green)) || name
      end

      list = app_arr.join(', ')
      $stdout.puts "Application apps on your account for stack: " +
        "#{$stdout.colorize(Base.stack[:name], :bold)}"
      $stdout.puts " #{$stdout.colorize(list, :bold)}"
    end

    def layers
      Base.fetch_stack

      layers = Base.aws_client.describe_layers(stack_id: Base.stack[:stack_id])

      max = 0
      layers[:layers].each do |layer|
        shortname = $stdout.colorize(layer[:shortname], :bold)
        max = shortname.length if max < shortname.length
      end

      layer_arr = layers[:layers].map do |layer|
        fmt = "%#{max}s"
        shortname = sprintf(fmt, $stdout.colorize(layer[:shortname], :bold))
        name = "[#{shortname}] #{layer[:name]}"
        if layer[:shortname] == Base.config[:layer]
          $stdout.colorize(name, :green) 
        else
          name
        end
      end

      $stdout.puts 'Application layers on your account:'
      $stdout.puts layer_arr
    end
  end
end