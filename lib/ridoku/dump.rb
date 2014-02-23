#
# Command: dump
#

require 'ridoku/base'

module Ridoku
  register :dump

  class Dump < Base

    def run
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil
      sub_sub_command = (command.length > 1 && command[2]) || nil

      case sub_command
      when 'stack'
        dump_stack(sub_sub_command == 'all')
      when 'custom'
        dump_custom(sub_sub_command == 'all')
      when 'app'
        dump_app(sub_sub_command == 'all')
      when 'layer'
        dump_layer(sub_sub_command == 'all')
      when 'instance'
        dump_instance
      else
        print_dump_help
      end
    end

    protected

    def print_dump_help
      $stderr.puts <<-EOF
  Command: dump

  List/Modify the current app's database configuration.
    dump                 displays this list
    dump:stack[:all]     dump stack json or :all stack jsons
    dump:custom[:all]    dump stack's custom json only
    dump:app[:all]       dump app json or :all app jsons for specified stack
    dump:layer[:all]     dump layer json or :all layer jsons for specified stack
    dump:instance        dump instance json
    EOF
    end

    def dump_custom(all = false)
      Base.fetch_stack

      if all
        $stdout.print '['
        Base.stack_list.each { |st| custom(st, true) }
        $stdout.puts ']'
      else
        custom(Base.stack)
      end
    end

    def dump_stack(all = false)
      Base.fetch_stack

      if all
        $stdout.print '['
        Base.stack_list.each { |st| stack(st, true) }
        $stdout.puts ']'
      else
        stack(Base.stack)
      end
    end

    def dump_app(all = false)
      Base.fetch_app

      if all
        $stdout.print '['
        Base.app_list.each { |ap| app(ap, true) }
        $stdout.puts ']'
      else
        app(Base.app)
      end
    end

    def dump_layer(all = false)
      Base.fetch_layer(Base.config[:layer] || :all)

      $stdout.print '['
      if all
        Base.layer_list.each { |ly| layer(ly) }
      else
        Base.layers.each { |ly| layer(ly)  }
      end
      $stdout.puts ']'
    end

    def dump_instance
      Base.fetch_instance
      $stdout.print '['
      Base.instances.each { |ist| instance(ist) }
      $stdout.puts ']'
    end

    def stack(st, multiple = false)
      $stdout.print st.to_json
      $stdout.print ',' if multiple
      $stdout.puts
    end

    def custom(st, multiple = false)
      $stdout.print st[:custom_json].to_json
      $stdout.print ',' if multiple
      $stdout.puts
    end

    def app(ap, multiple = false)
      $stdout.print ap.to_json
      $stdout.print ',' if multiple
      $stdout.puts
    end

    def layer(ly)
      $stdout.print ly.to_json
      $stdout.puts ','
    end

    def instance(ist)
      $stdout.print ist.to_json
      $stdout.puts ','
    end
  end
end