#
# Command: list-apps
# Description: Used to list all stacks on an AWS OpsStack account.
#   The current selection is colorized green.
#

def run_command(client)
  stacks = client.describe_stacks
  stack_arr = stacks[:stacks].map do |stack|
    name = stack[:name]
    (name == @config[:app] && name.green) || name
  end

  $stdout.puts 'Application stacks on your account:'
  $stdout.puts " #{stack_arr.join(', ').bold}"
end