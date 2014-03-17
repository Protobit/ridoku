# encoding: utf-8

module Ridoku
  module Services
    add_service :postgres

    class Postgres
      attr_accessor :postgresql

      def run(cmd, args)
        sub_command = args.shift

        case cmd
        when 'config'
          config(sub_command)
        when 'describe', 'list', 'show', nil
          show(sub_command)
        else
          print_help
        end
      end

      def print_help
        $stderr.puts <<-EOF
Command: service postgres

List/Modify the current app's associated workers.
  postgres[:config]   lists configuration

        EOF
      end

      def setup
        Ridoku::Base.fetch_stack
        self.postgresql = (Base.custom_json['postgresql'] ||= {})
      end

      def config(sub)
        $stderr.puts ''
      end

      def show_url()
        Ridoku::Base.fetch_app
        Ridoku::Base.fetch_instance('postgresql', force: true)

        app = Ridoku::Base.app[:shortname]
        dbase = postgresql['databases'].select do |db|
          db['app'] == app
        end.first

        unless dbase
          $stderr.puts "Application #{$stderr.colorize('app', :red)} has no "\
            "databases configured."
          return
        end

        dbase['adapter'] = 'postgres'
        dbase['password'] = dbase['user_password']
        dbase['port'] = postgresql['config']['port']
        dbase['host'] = Ridoku::Base.instances.first[:public_ip]

        $stdout.puts $stdout.colorize(Ridoku::Db.gen_dbase_url(dbase), :bold)
      end

      def show(sub)
        setup

        if sub == 'url'
          return show_url
        end

        $stdout.puts 'Postgresql configuration:'
        puts JSON.pretty_generate(postgresql)
      end
    end
  end
end