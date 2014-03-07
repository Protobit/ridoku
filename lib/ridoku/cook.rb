#
# Command: cook
#

require 'rugged'
require 'ridoku/base'

module Ridoku
  register :cook

  class Cook < Base

    def run      
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil

      Base.fetch_stack

      case sub_command
      # when 'list', nil
      #   list
      when 'update'
        update
      when 'run'
        cook
      else
        print_cook_help
      end
    end

    protected

    def extract_instance_ids
      Base.fetch_instance(Base.config[:layers] || :all)

      names = Base.config[:instances] || []
      instances = Base.instances.select do |inst|
        if names.length > 0
          names.index(inst[:hostname]) != nil && inst[:status] != 'offline'
        else
          inst[:status] == 'online'
        end
      end

      instances.map do |inst|
        inst[:instance_id]
      end
    end

    def list
      update unless File.exists?(cookbook_path)
    end

    def update
      $stdout.puts "Updating custom cookbooks..."

      Base.run_command(Base.update_cookbooks(extract_instance_ids))
    end

    def valid_recipe_format?
      return false if ARGV.length == 0

      recipe = %r(^[a-zA-Z0-9_\-]+(::[a-zA-Z0-9_\-]+){0,1}$)
      ARGV.each do |cr|
        return false unless cr.match(recipe)
      end

      true
    end

    def cook
      unless valid_recipe_format?
        $stderr.puts 'Invalid recipes provided.'
        print_cook_help
        exit 1
      end

      instance_ids = extract_instance_ids

      if instance_ids.length == 0
        $stderr.puts 'No valid instances available.'
        exit 1
      end

      $stdout.puts "Running recipes:"
      ARGV.each do |arg|
        $stdout.puts "  #{$stdout.colorize(arg, :green)}"
      end

      command = Base.execute_recipes(Base.app[:app_id], instances, ARGV,
        Base.config[:comment])

      Base.run_command(command)
    end

    def print_cook_help
      $stderr.puts <<-EOF
  Command: cook

  List/Modify the current app's associated domains.
    cook:run      run a specific or set of 'cookbook::recipe'
    cook:update   update the specified instance 'cookboooks'
  EOF
    end
  end
end