# encoding: utf-8

module Ridoku
  module Services
    add_service :rabbitmq

    class Rabbitmq
      attr_accessor :mqconfig

      def run(cmd, args)
        sub_command = args.shift

        case cmd
        when 'config', nil
          config(sub_command)
        when 'describe', 'list', 'show'
          show(sub_command)
        else
          print_help
        end
      end

      def print_help
        $stderr.puts <<-EOF
Command: service:change rabbitmq

List/Modify the current app's associated workers.
  rabbitmq[:config]   lists configuration

        EOF
      end

      def setup
        Ridoku::Base.fetch_stack
        self.mqconfig = (Base.custom_json['rabbitmq'] ||= {})
      end

      def config(sub)
        $stderr.puts 'RabbitMQ Config'
      end

      def show(sub)
        setup
        puts JSON.pretty_generate(mqconfig)
      end
    end
  end
end