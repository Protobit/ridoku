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

    def list
      update unless File.exists?(cookbook_path)
    end

    def update
      $stdout.puts "Updating custom cookbooks..."

      Base.run_command(Base.update_cookbooks(Base.extract_instance_ids))
    end

    class << self
      def valid_recipe_format?(recipes)
        return false if recipes.length == 0

        recipe = %r(^[a-zA-Z0-9_\-]+(::[a-zA-Z0-9_\-]+){0,1}$)
        recipes.each do |cr|
          return false unless cr.match(recipe)
        end

        true
      end

      def cook_recipe(recipes) 
        Base.fetch_app

        recipes = [recipes] unless recipes.is_a?(Array)

        unless valid_recipe_format?(recipes)
          $stderr.puts 'Invalid recipes provided.'
          print_cook_help
          exit 1
        end

        instance_ids = Base.extract_instance_ids

        if instance_ids.length == 0
          $stderr.puts 'No valid instances available.'
          exit 1
        end

        $stdout.puts "Running recipes:"
        recipes.each do |arg|
          $stdout.puts "  #{$stdout.colorize(arg, :green)}"
        end

        command = Base.execute_recipes(Base.app[:app_id], instance_ids,
          Base.config[:comment], recipes)

        Base.run_command(command)
      end
    end

    def cook
      self.cook_recipe(ARGV)
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