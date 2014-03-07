require 'getoptlong'

module Ridoku
  def self.init_options
    @options = [
      [ '--debug', '-D', GetoptLong::NO_ARGUMENT,<<-EOF

       Turn on debugging outputs (for AWS and Exceptions).
    EOF
      ],
      [ '--no-wait', '-n', GetoptLong::NO_ARGUMENT,<<-EOF

       When issuing a command, do not wait for the command to return.
    EOF
      ],
      [ '--key', '-k', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<key>
       Use the specified key as the AWS_ACCESS_KEY   
    EOF
      ],
      [ '--secret', '-s', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<secret>
       Use the specified secret as the AWS_SECRET_KEY   
    EOF
      ],
      [ '--set-app', '-A', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<app>
       Use the specified App as the default Application.
    EOF
      ],
      [ '--set-backup-bucket', '-B', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<bucket name>
       Use the specified bucket name as the default Backup Bucket.
    EOF
      ],
      [ '--backup-bucket', '-b', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<bucket name>
       Use the specified bucket name as the current Backup Bucket.
    EOF
      ],
      [ '--set-stack', '-S', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<stack>
       Use the specified Stack as the default Stack.
    EOF
      ],
      [ '--set-user', '-U', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<user>
       Use the specified user as the default login user in 'run:shell'.
    EOF
      ],
      [ '--set-ssh-key', '-K', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<key file>
       Use the specified file as the default ssh key file.
    EOF
      ],
      [ '--ssh-key', '-f', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<key file>
       Override the default ssh key file for this call.
    EOF
      ],
      [ '--app', '-a', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<app>
       Override the default App name for this call.
    EOF
      ],
      [ '--stack', '-t', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<stack>
       Override the default Stack name for this call.
    EOF
      ],
      [ '--instances', '-i', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<instances>
       Run command on specified instances; valid delimiters: ',' or ':'
       example:
         ridoku deploy --instances mukujara,tanuki
    EOF
      ],
      [ '--user', '-u', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<user>
       Override the default user name for this call.
    EOF
      ],
      [ '--comment', '-m', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<message>
       Optional for: #{$stderr.colorize('deploy', :bold)}
       Add the specified message to the deploy:* action.
    EOF
      ],
      [ '--domains', '-d', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
<domains>
       Optional for: #{$stderr.colorize('create:app', :bold)}
       Add the specified domains to the newly created application.
    EOF
      ],
      [ '--layer', '-l', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
    EOF
      ],
      [ '--repo', '-r', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
    EOF
      ],
      [ '--service-arn', '-V', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
    EOF
      ],
      [ '--instance-arn', '-N', GetoptLong::REQUIRED_ARGUMENT,<<-EOF
    EOF
      ],
      [ '--practice', '-p', GetoptLong::NO_ARGUMENT,<<-EOF
    EOF
      ],
      [ '--wizard', '-w', GetoptLong::NO_ARGUMENT,<<-EOF
    EOF
      ],
    ]
  end

  def self.add_options(opts)
    @options<< opts
  end

  def self.options
    @options
  end

  init_options
end