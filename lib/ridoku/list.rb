#
# Command: list
# Description: Used to list all stacks on an AWS OpsStack account.
#   The current selection is colorized green.
#

require 'ridoku/base'

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

      when 'instances'
        instances

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
       list           lists stacks or apps if stack is specified
       list:config    lists current configuration information (app, stack, etc)
       list:stacks    lists stacks by name
       list:apps      lists apps if stack is specified
       list:layers    lists layers if stack is specified
       list:instances lists instances by layer
      EOF
    end

    def config
      config = [
        'Current:',
        "  #{$stdout.colorize('Stack', :bold)}: #{Base.config[:stack]}",
        "  #{$stdout.colorize('App', :bold)}: #{Base.config[:app]}",
        "  #{$stdout.colorize('Shell User', :bold)}: #{Base.config[:shell_user]}",
        "  #{$stdout.colorize('Service ARN', :bold)}: #{Base.config[:service_arn]}",
        "  #{$stdout.colorize('Instance ARN', :bold)}: #{Base.config[:instance_arn]}",
        "  #{$stdout.colorize('Default SSH Key', :bold)}: #{Base.config[:ssh_key]}",
      ]
      $stdout.puts config
    end

    def stacks
      Base.fetch_stack

      stack_arr = Base.stack_list.map do |stack|
        name = stack[:name]
        (name == Base.config[:stack] && $stdout.colorize(name, :green)) || name
      end

      list = stack_arr.join(', ')
      $stdout.puts 'Application stacks on your account:'
      $stdout.puts " #{$stdout.colorize(list, :bold)}"
    end

    def apps
      Base.fetch_app

      app_arr = Base.app_list.map do |app|
        name = app[:name]
        (name == Base.config[:app] && $stdout.colorize(name, :green)) || name
      end

      list = app_arr.join(', ')
      $stdout.puts "Application apps on stack " +
        "#{$stdout.colorize(Base.stack[:name], [:green, :bold])}:"
      $stdout.puts " #{$stdout.colorize(list, :bold)}"
    end

    def layers
      Base.fetch_layer

      max = 0
      Base.layer_list.each do |layer|
        shortname = $stdout.colorize(layer[:shortname], :bold)
        max = shortname.length if max < shortname.length
      end

      layer_arr = Base.layer_list.map do |layer|
        fmt = "%#{max}s"
        shortname = sprintf(fmt, $stdout.colorize(layer[:shortname], :bold))
        name = "[#{shortname}] #{layer[:name]}"
        if layer[:shortname] == Base.config[:layer]
          $stdout.colorize(name, :green) 
        else
          name
        end
      end

      $stdout.puts 'Layers on stack ' +
        "#{$stdout.colorize(Base.stack[:name], [:bold, :green])}:"
      $stdout.puts layer_arr
    end

    def instances
      Base.fetch_layer
      Base.fetch_instance

      $stdout.puts 'Application instances on stack ' +
        "#{$stdout.colorize(Base.stack[:name], [:bold, :green])}:"


      Base.layer_list.each do |layer|
        selected = Base.config[:instances]

        linstances = Base.instances.select do |inst|
          inst[:layer_ids].index(layer[:layer_id]) != nil
        end

        instance_arr = linstances.map do |instance|
          name = "  #{instance[:hostname]}: #{$stdout.colorize(
            instance[:status], instance[:status] == 'online' ? :green : :red)}"
          if selected && selected.index(instance[:hostname]) != nil
            $stdout.colorize(name, :green) 
          else
            name
          end
        end

        name = "Layer: #{layer[:name]} [#{layer[:shortname]}]"

        $stdout.puts (layer[:shortname] == Base.config[:layer] &&
          $stdout.colorize(name, :green)) || name

        if instance_arr.length
          $stdout.puts instance_arr
        else
          $stdout.puts '  No instances in this layer.'
        end
        $stdout.puts
      end
    end
  end
end