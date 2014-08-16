#
# Command: maintenance
#

require 'ridoku/base'

module Ridoku
  register :maintenance

  class Maintenance < Base
    attr_accessor :app

    def run
      clist = Base.config[:command]
      command = clist.shift
      sub_command = clist.shift

      case sub_command
      when 'on'
        maintenance(true)
      when 'off'
        maintenance(false)
      when 'status', nil
        status
      else
        print_maintenance_help
      end
    end

    protected

    def maintenance(maint)
      Base.fetch_stack
      Base.fetch_app

      Base.custom_json['deploy'][Base.app[:shortname]]['maintenance'] = maint
      Base.save_stack

      Ridoku::Cook.cook_recipe_on_layers('deploy::maintenance', ['rails-app'],
        deploy: {
          Base.app[:shortname] => {
            application_type: 'rails'
          }
        }
      )
      status
    end

    def status
      Base.fetch_stack
      Base.fetch_app

      $stdout.print 'Maintenance: '

      app_json = Base.custom_json['deploy'][Base.app[:shortname]]

      if app_json.key?('maintenance')
        maint = app_json['maintenance'] == 'true'
        $stdout.puts $stdout.colorize((maint ? 'on' : 'off'),
          [:bold, (maint ? :red : :green)])
      else
        $stdout.puts $stdout.colorize('off', :green)
      end
    end

    def print_maintenance_help
      $stderr.puts <<-EOF
Command: maintenance

Set maintenance mode on the specific applications:
  maintenance:on   Turn on maintenance mode for all application instances.
  maintenance:off  Turn off maintenance mode for all application instances.
EOF
    end
  end
end