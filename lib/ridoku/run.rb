#
# Command: run
#

require 'ridoku/base'

module Ridoku
  class Run < Base
    attr_accessor :environment
    
    def run      
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil

      case sub_command
      when 'command', nil
        run_command
      when 'shell'
        shell
      else
        print_run_help
      end
    end

    protected

    def load_environment
      Base.fetch_stack
      Base.fetch_app

      self.environment =
        Base.custom_json['deploy'][Base.config[:app].downcase]['app_env']
    end

    def create_ssh_path
      Base.fetch_instance
      Base.fetch_account

      instance = Base.select_instances(Base.config[:instances]).first

      unless instance
        $stderr.puts 'Unable to find a valid instance.'
        print_run_help
        exit 1
      end

      username = Base.account[:user][:user_name].gsub!(/[.]/, '')
      "#{username}@#{instance[:elastic_ip] || instance[:public_ip]}"
    end

    def ssh_command(command = nil)
      Base.fetch_app
      Base.fetch_permissions
      
      load_environment

      fail Ridoku::NoSshAccess.new unless
        Base.permissions[:permissions].first[:allow_ssh]
      
      if Base.permissions[:permissions].first[:allow_sudo]
        chdir = "cd /srv/www/#{Base.app[:shortname]}/current"
        prefix = "sudo su #{Base.config[:shell_user] || 'root'} -c "
        prompt_cmd = "#{chdir};"
      else
        prompt_cmd = ''
        prefix = ''
      end

      environ = environment.map do |key, val|
        "#{key}='#{val}'"
      end.join(' ')

      network_path = create_ssh_path
      bash_command = (command && "-c \\\\\\\"#{chdir} && #{command}\\\\\\\"") || ''

      %Q(/usr/bin/env ssh -t #{network_path} "#{prefix} \\"#{prompt_cmd} #{environ} bash #{bash_command}\\"")
    end

    def shell
      exec ssh_command
    end

    def run_command
      exec ssh_command(ARGV.join(' '))
    end

    def print_run_help
      $stderr.puts <<-EOF
  Command: run

  Run the specified command on an instance:
    run[:command] run a command (over ssh) in the release directory
    run:shell     ssh to the specified instance
      --instance  specify the instance (max: 1)
      --user      ssh as user (default: root; optionally: <AWS Username>,
                    or deploy)

  examples:
    $ run:shell
    mukujara$
    EOF
    end
  end
end