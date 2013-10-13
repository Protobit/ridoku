#
# Command: config
# Description: List/Modify the current apps configuration.
#  config - lists the key value pairs
#  config:set KEY:VALUE [...]
#  config:delete KEY
#

def get_app_environment
  @custom = JSON.parse(@stack[:custom_json])
  @custom['deploy'][@config[:app].downcase]['app_env']
end

def save_stack(client)
  client.update_stack(
    stack_id: @stack[:stack_id],
    custom_json: @custom.to_json,
    service_role_arn: @stack[:service_role_arn]
  )
end

def print_config_help
  $stderr.puts <<-EOF
Command: config

List/Modify the current app's environment.
   config        lists the key value pairs
   config:set    KEY:VALUE [...]
   config:delete KEY [...]

examples:
  $ config
  Environment Empty!
  $ config:set AWS_ACCESS_KEY:'jas8dyfawenfi9f'
  $ config:set AWS_SECRET_KEY:'SJHDF3HSDOFJS4DFJ3E'
  $ config:delete AWS_SECRET_KEY
  $ config
  Environment:
    AWS_ACCESS_KEY: 'jas8dyfawenfi9f'
  EOF
end

def list_environment
  environ = get_app_environment

  if environ.keys.length == 0
    $stdout.puts 'Environment Empty!'
  else
    $stdout.puts 'Environment:'
    environ.each do |key, value|
      $stdout.puts "  #{key.bold}: '#{value}'"
    end
  end
end

def add_environment(client)
  environ = get_app_environment

  ARGV.each do |kvpair|
    kvpair.match(%r((^[^:]+):(.*))) do |m|
      key = m[1]
      value = m[2]

      update = environ.key?(key)
      environ[key] = value
      $stdout.puts "#{update && 'Updating' || 'Adding'}: #{key} as '#{value}'"
    end
  end

  save_stack(client)
end

def delete_environment(client)
  environ = get_app_environment

  ARGV.each do |key|
    value = environ.delete(key)
    $stdout.puts "Deleting key: #{key}, '#{value}'"
  end
  
  save_stack(client)
end

def run_command(client)
  command = @config[:command]
  sub_command = (command.length > 0 && command[1]) || nil
  case sub_command
  when 'list', nil
    list_environment

  when 'set'
    add_environment(client)

  when 'delete'
    delete_environment(client)

  when 'help'
    print_config_help

  else
    $stderr.puts "Invalid sub-command: #{sub_command}"
    print_config_help
    exit 1
  end
end