#
# Command: db
# Description: List/Modify the current apps database configuration
#  db - lists the database parameters
#  config:set KEY:VALUE [...]
#  config:delete KEY
#

require 'ridoku/base'

module Ridoku
  class Db < Base
    attr_accessor :dbase

    def run
      command = Base.config[:command]
      sub_command = (command.length > 0 && command[1]) || nil
      sub_sub_command = (command.length > 1 && command[2]) || nil

      load_database

      case sub_command
      when 'list', nil, 'info'
        list(false)
      when 'credentials'
        list(true)
      when 'set', 'add'
        set
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
      self.dbase =
        Base.custom_json['deploy'][Base.config[:app].downcase]['database']
    end

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

    def print_db_help
      $stderr.puts <<-EOF
    Command: database

    List/Modify the current app's database configuration.
       db           lists the key value pairs
       db:set:url  attribute:value [...]
       db:delete    attribute [...]
       db:url      get the URL form of the database info
       db:url:set  set attributes using a URL

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

    def list(cred)
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
        dbase['adapter'] = adapter_from_scheme(m[1])
        dbase['username'] = m[2]
        dbase['password'] = m[3]
        dbase['host'] = m[4]
        dbase['port'] = m[5]
        dbase['database'] = m[6]
      end
    end

    def get_url_database
      scheme = scheme_from_adapter(dbase['adapter'])
      username = dbase['username']
      password = dbase['password']
      host = dbase['host']
      port = dbase['port']
      database = dbase['database']

      unless database && scheme && host
        $stdout.puts $stdout.colorize(
          "One or more required fields are not specified!",
          :bold
        )
        $stdout.puts $stdout.colorize("adapter, host, and database", :red)
        list_database
      end

      url = "#{scheme}://"
      url += username if username
      url += ":#{password}"
      url += '@' if username || password
      url += host
      url += ":#{port}" if port
      url += "/#{database}" if database
      $stdout.puts $stdout.colorize(url, :bold)
    end

    def url(subc)
      if subc
        set_url_database(subc)
        Base.save_stack
      else
        get_url_database
      end
    end
  end
end