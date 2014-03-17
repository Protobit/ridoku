#
# Command: db
# Description: List/Modify the current apps database configuration
#  db - lists the database parameters
#  config:set KEY:VALUE [...]
#  config:delete KEY
#

require 'ridoku/base'

module Ridoku
  register :db

  class Db < Base
    attr_accessor :dbase

    def run
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil
      sub_sub_command = (command.length > 1 && command[2]) || nil

      case sub_command
      when 'list', nil, 'info'
        list(false)
      when 'credentials'
        list(true)
      when 'set', 'add'
        set
      when 'push', 'update'
        push_update
      when 'delete', 'remove', 'rm'
        delete
      when 'url', 'path'
        url(sub_sub_command)
      else
        print_db_help
      end
    end

    protected

    def load_database
      Base.fetch_stack
      Base.fetch_app
      self.dbase =
        Base.custom_json['deploy'][Base.app[:shortname]]['database']
    end

    def print_db_help
      $stderr.puts <<-EOF
Command: database

List/Modify the current app's database configuration.
   db           lists the key value pairs
   db:push      push changes to the servers
   db:set:url   attribute:value [...]
   db:delete    attribute [...]
   db:url       get the URL form of the database info
   db:url:set   set attributes using a URL

examples:
  $ db:set database:'Survly'
  Database:
    adapter: postgresql
    host: ec2-50-47-234-2.amazonaws.com
    port: 5234
    database: Survly
    username: survly
    reconnect: true
      EOF
    end

    def push_update
      if Base.config[:wait]
        $stdout.puts 'Disabling command wait (2 commands to issue)...' 
        Base.config[:wait] = false
      end

      Base.fetch_app

      cjson = {
        opsworks: {
          rails_stack: {
            restart_command: '../../shared/scripts/unicorn force-restart'
          }  
        },
        deploy: {
          Base.app[:shortname] => {
            application_type: 'rails'
          }
        }
      }

      begin
        $stdout.puts 'This operation will '\
          "#{$stdout.colorize('RESTART', :red)} (not soft reload) "\
          'your application.'
        sleep 2
        $stdout.puts 'Hold your seats: db push and force restart in... (Press CTRL-C to Stop)'
        5.times { |t| $stdout.print "#{$stdout.colorize(5-t, :red)} "; sleep 1 }
        $stdout.puts "\nSilence is acceptance..."
      rescue Interrupt
        $stdout.puts $stdout.colorize("\nCommand canceled", :green)
        exit 1
      end

      Base.config[:layers] = ['rails-app']
      Ridoku::Cook.cook_recipe('rails::configure', cjson)

      Base.config[:layers] = ['workers']
      Ridoku::Cook.cook_recipe('deploy::delayed_job-configure', cjson)
    end

    def list(cred)
      load_database
      if dbase.keys.length == 0
        $stdout.puts 'Database Not Configured!'
      else
        $stdout.puts 'Database:'
        dbase.each do |key, value|
          $stdout.puts "  #{$stdout.colorize(key, :bold)}: #{value}" if
            (cred || (key != 'password' && key != 'username'))
        end
      end
    end

    def set
      load_database
      ARGV.each do |kvpair|
        kvpair.match(%r((^[^:]+):(.*))) do |m|
          key = m[1]
          value = m[2]

          update = dbase.key?(key)
          dbase[key] = value
          $stdout.puts "#{update && 'Updating' || 'Adding'}: #{key} as '#{value}'"
        end
      end

      Base.save_stack
    end

    def delete
      load_database
      ARGV.each do |key|
        value = dbase.delete(key)
        $stdout.puts "Deleting key: #{key}, '#{value}'"
      end

      Base.save_stack
    end

    def set_url_database(subc)
      if subc != 'set'
        print_db_help 
        exit 1
      end

      regex = %r(^([^:]+)://([^:]+):([^@]+)@([^:]+):([^/]+)/(.*)$)
      ARGV[0].match(regex) do |m|
        dbase['adapter'] = Db.adapter_from_scheme(m[1])
        dbase['username'] = m[2]
        dbase['password'] = m[3]
        dbase['host'] = m[4]
        dbase['port'] = m[5]
        dbase['database'] = m[6]
      end
    end

    class << self
      def scheme_hash
        {
          'postgresql' => 'postgres',
          'mysql' => 'mysql'
        }
      end

      def scheme_from_adapter(adapter)
        val = scheme_hash
        return val[adapter] if val.key?(adapter)
        adapter
      end

      def adapter_from_scheme(scheme)
        val = scheme_hash.invert
        return val[scheme] if val.key?(scheme)
        scheme
      end

      def gen_dbase_url(dbase)
        scheme = scheme_from_adapter(dbase['adapter'])
        username = dbase['username']
        password = dbase['password']
        host = dbase['host']
        port = dbase['port']
        database = dbase['database']

        url = "#{scheme}://"
        url += username if username
        url += ":#{password}"
        url += '@' if username || password
        url += host
        url += ":#{port}" if port
        url += "/#{database}" if database
        url
      end
    end

    def get_url_database
      scheme = Db.scheme_from_adapter(dbase['adapter'])

      unless  dbase['database'] && scheme && dbase['host']
        $stdout.puts $stdout.colorize(
          "One or more required fields are not specified!",
          :bold
        )
        $stdout.puts $stdout.colorize("adapter, host, and database", :red)
        list_database
      end

      url = Db.gen_dbase_url(dbase)
      $stdout.puts $stdout.colorize(url, :bold)
    end

    def url(subc)
      load_database
      if subc
        set_url_database(subc)
        Base.save_stack
      else
        get_url_database
      end
    end
  end
end