# *ridoku* v0.8

*ridoku* is intended to be a set of scripts for replacing a Heroku work flow
with AWS OpsWorks.  It requires some manual configuration at the moment in 
AWS OpsWorks and the IAM Control Panel.

## User Configuration

You must add a user or add full permission to OpsWorks to your existing user.  
The easiest way to do this is by following [this guide](http://docs.aws.amazon.com/opsworks/latest/userguide/opsworks-security-users.html).  Once you have this
completed, you should be able to use `ridoku` to manage certain aspects of
your app deployment.

## Stack Configuration

Currently, *ridoku* only works with the Rails Application Stack (rather, its
only been tested on the stack, and several layer-actions specify 'rails-app'
type, so your mileage may vary).

Also, when developing the scripts, I was using a Rails app with a custom
PostgreSQL, so the use of the OpsWorks MySQL layer has not been tested, but
probably won't be affected (it will probably only limit the use of the
[ridoku db](#db) command set for application management).

Once the Stack has been created and instances added using the OpsWorks GUI, 
you should be able to start using *ridoku* to make edits to your database and
environment information, as well as running recipes and commands on the stack.

Sadly, at this point, the OpsWorks GUI is still required (stack config, layers,
etc are manual atm).

## Custom Cookbooks

Currently, the Ridoku custom cookbooks are also required to ensure that the
environment is the same as is expected by a Heroku application.

## Quickstart

If you have a Stack that is already configured to use *ridoku*, this section
gives you a quick run-down of commands necessary for Application management.

(`rid` can also be used as an alias for `ridoku`)

Each command below expects you to have run:

```
$ ridoku --set-stack YourStack
$ ridoku --set-app YourApp
$ ridoku --set-backup-bucket YourBackupBucket
```

The switches `--app app-name` and `--stack stack-name` can be used in any given
commandline to override defaults.

### Deploy/Rollback

`$ ridoku deploy`

Deploys the application to all instances.
Note that **HEAD** is used for the repository branch associated with this app.
(This is currently only configurable in the OpsWorks console)

`$ ridoku deploy:rollback`

Rollback the application on all instances.

### Database Backup

These commands only work if you are using *ridoku* to manage databases.

`$ ridoku backup:capture`

Captures the current applications database and stores it to S3.


```
$ ridoku backup:list
$ ridoku backup:capture
$ ridoku backup:restore <backup name>
```

Shows all existing database backups for the specified application,
captures a backup (safety first!), then restores the specified database backup.

### Environment

*compare to `heroku config`*

All changes to the environment require an application `deploy` to take effect.
The Revision provider is used in the *ridoku* deployment cookbooks.  As a result,
multiple deploy commands can be issued in a row without depleting the `rollback`
capability (which is limited to 5 total rollbacks).

`$ ridoku env`

Displays the current applications runtime environment configuration.

`$ ridoku env:set KEY:value KEY2:value2`

Sets or updates the specified key/value pairs.

`$ ridoku env:remove KEY`

Removes the specified key/value pair.

## *ridoku* commands

Ridoku, 0.0.8

`usage: ridoku [OPTIONS] command [command options]`

### backup

**TODO**

### cook

**TODO**

### create

**TODO**

### db

**TODO**

### deploy

**TODO**

### domain

**TODO**

### dump

**TODO**

### env

**TODO**

### list

**TODO**

### packages

**TODO**

### run

**TODO**

### service

**TODO**

### workers

**TODO**

### Options:

|CL Switch|Description|
|---|---|
|--debug/-D|Turn on debugging outputs (for AWS and Exceptions).|
|--no-wait/-n|When issuing a command, do not wait for the command to return.|
|--key/-k &lt;key&gt;|Use the specified key as the AWS_ACCESS_KEY|
|--secret/-s &lt;secret&gt;|Use the specified secret as the AWS_SECRET_KEY|
|--set-app/-A &lt;app&gt;|Use the specified App as the default Application.|
|--set-backup-bucket/-B &lt;bucket name&gt;|Use the specified bucket name as the default Backup Bucket.|
|--backup-bucket/-b &lt;bucket name&gt;|Use the specified bucket name as the current Backup Bucket.|
|--set-stack/-S &lt;stack&gt;|Use the specified Stack as the default Stack.|
|--set-user/-U &lt;user&gt;|Use the specified user as the default login user in 'run:shell'.|
|--set-ssh-key/-K &lt;key file&gt;|Use the specified file as the default ssh key file.|
|--ssh-key/-f &lt;key file&gt;|Override the default ssh key file for this call.|
|--app/-a &lt;app&gt;|Override the default App name for this call.|
|--stack/-t &lt;stack&gt;|Override the default Stack name for this call.|
|--instances/-i &lt;instances&gt;|Run command on specified instances; valid delimiters: ',' or ':'|
|--user/-u &lt;user&gt;|Override the default user name for this call.|
|--comment/-m &lt;message&gt;|Optional for: deploy|
|--domains/-d &lt;domains&gt;|Optional for: create:app. Add the specified domains to the newly created application.|
|--layer/-l|**TODO**|
|--repo/-r|**TODO**|
|--service-arn/-V|**TODO**|
|--instance-arn/-N|**TODO**|
|--practice/-p|**TODO**|
|--wizard/-w|**TODO**|

## Configuration Wizard:

In order to get ridoku configured with your OpsWorks account, Ridoku must
collect pertinent required info. The wizard can be run at any time after the
first with the command line option of `--wizard`.

### Values to be configured:

#### ssh_key:
     
Path to the SSH key to be used for git repositories
(cook books, apps, etc).  It is recommended that this be generated
separately from your personal SSH keys so that they can be revoked
effecting other logins.

#### service_role_arn:

If a valid service_role_arn cannot be found, Ridoku will attempt to
generate one for you.  If you've already used OpsWorks, Ridoku should be
able to find the necessary Roles for you.

#### instance_role_arn:

If a valid instance_role_arn cannot be found, Ridoku will attempt to
generate one for you.  If you've already used OpsWorks, Ridoku should be
able to find the necessary Roles for you.


## Apps and Stacks:

Amazon OpsWorks similarly to Heroku, but, because you manage all the resources,
you'll have to provide a bit more information than you do to Heroku in order
for this commandline utility to assist.

### Stacks:
  The technology stack to use for a particular type of application.

Heroku probably has a similar structure internally, because they allow
you to use any number of program Stacks (Rails, PHP, Python, Go, etc).
The difference is that now in OpsWorks you control the stack environment,
where on Heroku you did not.

If you have a stack configured, you can view pertinent information using

`$ ridoku list:stacks`

This will display the stacks that are currently associated with your AWS
account.  To

To set the specific stack to use:

`$ ridoku --set-stack <stackname>`

To set a single run stack or override the default:

`$ ridoku --stack <stackname> --app <appname> command…`

### Apps:
  The actual application which runs on the technology stack.

This is what you have control over on Heroku.  You can customize the app
domains, database information, environment, etc, on a per-application
basis.  The same goes for OpsWorks.

To set the default app to use:

`$ ridoku --set-app <stackname>`

To set a specific run app or override the default:

`$ ridoku --stack <stackname> --app <appname> command…`

## Future

I would like to get this to the point of a fully functional Heroku replacement.
Adding a standard `Rails` stack using the standard `LB -> Web Server*N <-> DB` stack
layout should be fairly easily accomplished.

If you have any issues when attempting to use this toolchain, please feel free
to submit a pull request.