#
# Command: deploy
#

require "#{File.dirname(__FILE__)}/base.rb"

module Ridoku
  class Deploy < Base
    attr_accessor :app
    def run
      Base.fetch_stack
      fetch_app
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil

      case sub_command
      when 'to'
        to(ARGV)
      when 'info'
        info
      when 'help'
        print_deploy_help
        exit 0
      else
        deploy_default
      end
    end

    protected

    def fetch_app
      apps = Base.aws_client.describe_apps(stack_id: Base.stack[:stack_id])
      apps[:apps]
    end

    def to(instances)
    end

    def default
    end

    def info
    end

    def print_deploy_help      
      $stderr.puts <<-EOF
    Command: deploy

    Deploy this application.
       deploy        deploy to all active instances
       deploy:to     deploy to specific instance only (use: list:instances to
                     see available instances)
       deploy:help   show this message
       

    examples:
      $ deploy
      Deploying to 2 instances:
        mukujara, hinoenma
      Using git repository:
        git@github.com:ridoku/example-app.git @ master
      This may take a while...
      Successfully Deployed
      EOF
    end
  end
end