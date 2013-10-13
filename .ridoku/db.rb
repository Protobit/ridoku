#
# Command: db
# Description: List/Modify the current apps database configuration
#  db - lists the database parameters
#  config:set KEY:VALUE [...]
#  config:delete KEY
#

def get_app_database
  @custom = JSON.parse(@stack[:custom_json])
  @custom['deploy'][@config[:app].downcase]['database']
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

def save_stack(client)
  client.update_stack(
    stack_id: @stack[:stack_id],
    custom_json: @custom.to_json,
    service_role_arn: @stack[:service_role_arn]
  )
end

def print_db_help
  $stderr.puts <<-EOF
Command: config

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

def list_database(cred)
  dbase = get_app_database

  if dbase.keys.length == 0
    $stdout.puts 'Database Not Configured!'
  else
    $stdout.puts 'Database:'
    dbase.each do |key, value|
      $stdout.puts "  #{key.bold}: #{value}" if
        (cred || (key != 'password' && key != 'username'))
    end
  end
end

def add_database(client)
  dbase = get_app_database

  ARGV.each do |kvpair|
    kvpair.match(%r((^[^:]+):(.*))) do |m|
      key = m[1]
      value = m[2]

      update = dbase.key?(key)
      dbase[key] = value
      $stdout.puts "#{update && 'Updating' || 'Adding'}: #{key} as '#{value}'"
    end
  end

  save_stack(client)
end

def delete_database(client)
  dbase = get_app_database

  ARGV.each do |key|
    value = dbase.delete(key)
    $stdout.puts "Deleting key: #{key}, '#{value}'"
  end

  save_stack(client)
end

def set_url_database(subc)
  dbase = get_app_database

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
  dbase = get_app_database

  scheme = scheme_from_adapter(dbase['adapter'])
  username = dbase['username']
  password = dbase['password']
  host = dbase['host']
  port = dbase['port']
  database = dbase['database']

  unless database && scheme && host
    puts "One or more required fields are not specified!".bold
    puts "adapter, host, and database".red
    list_database
  end

  url = "#{scheme}://"
  url += username if username
  url += ":#{password}"
  url += '@' if username || password
  url += host
  url += ":#{port}" if port
  url += "/#{database}" if database
  $stdout.puts url.bold
end

def url_database(client, subc)
  if subc
    set_url_database(subc)
    save_stack(client)
  else
    get_url_database
  end
end

def run_command(client)
  command = @config[:command]
  sub_command = (command.length > 0 && command[1]) || nil
  sub_sub_command = (command.length > 1 && command[2]) || nil
  case sub_command
  when 'list', nil, 'info'
    list_database(false)

  when 'credentials'
    list_database(true)

  when 'set', 'add'
    add_database(client)

  when 'delete', 'remove', 'rm'
    delete_database(client)

  when 'url', 'path'
    url_database(client, sub_sub_command)

  when 'help', '?'
    print_config_help

  else
    $stderr.puts "Invalid sub-command: #{sub_command}"
    print_db_help
    exit 1
  end
end