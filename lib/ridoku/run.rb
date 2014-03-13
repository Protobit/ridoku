#
# Command: run
#

require 'ridoku/base'

module Ridoku
  register :run

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

    class << self
      def create_ssh_path
        Base.fetch_instance
        Base.fetch_account

        instance = Base.select_instances(Base.config[:instances]).first

        unless instance
          $stderr.puts 'Unable to find a valid instance.'
          print_run_help
          exit 1
        end

        username = Base.account[:user][:user_name].gsub(/[.]/, '')
        "#{username}@#{instance[:elastic_ip] || instance[:public_ip]}"
      end

      def command(command = nil, relative_command = true)
        Base.fetch_app
        Base.fetch_permissions
        
        Base.fetch_stack
        
        # stupid fucking escaping bullshit
        # So, ruby escapes, so does bash, so does ssh
        # (all interpreter layers)
        # Sooo, we have to have an OMFG ridiculous number of backslashes...
        # to escape one mother fucking value.

        # TODO: The entire 'run' system is fucked.  Rethink it.
        command.gsub!(/\$/, '\\'*14 + '$') if command

        environment =
          Base.custom_json['deploy'][Base.config[:app].downcase]['app_env']

        fail Ridoku::NoSshAccess.new unless
          Base.permissions[:permissions].first[:allow_ssh]
        
        if Base.permissions[:permissions].first[:allow_sudo]
          prefix = "sudo su #{Base.config[:shell_user] || 'root'} -c "
        else
          prefix = ''
        end

        environ = environment.map do |key, val|
          "#{key}='#{val}'"
        end.join(' ')

        dir = "/srv/www/#{Base.config[:app]}/current"
        chdir = "cd #{dir}"
        path = "PATH=/usr/local/bin:#{dir}/script/:${PATH}"
        network_path = create_ssh_path

        relative = relative_command ? '/usr/bin/env' : ''

        bash_command = (command && "-c \\\\\\\"#{chdir} && #{relative} #{command}\\\\\\\"") || ''

        %Q(/usr/bin/env ssh -t #{network_path} "#{prefix} \\"#{environ} #{path} bash #{bash_command}\\"")
      end
    end

    def shell
      exec Ridoku::Run.command
    end

    def run_command
      exec Ridoku::Run.command(ARGV.join(' '))
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