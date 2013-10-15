# *ridoku* v0.1a

*ridoku* is intended to be a set of scripts for replacing a Heroku work flow
with AWS OpsWorks.  It requires some manual configuration at the moment in 
AWS OpsWorks and the IAM Control Panel.

## User Configuration

You must add a user or add full permission to OpsWorks to your existing user.  
The easiest way to do this is by following [this guide](http://docs.aws.amazon.com/opsworks/latest/userguide/opsworks-security-users.html).  Once you have this
completed, you should be able to use `ridoku-cli` to manage certain aspects of
your app deployment.

## Stack Configuration

Currently, *ridoku* only works with the Rails Application Stack (rather, its
only been tested on the stack, and several layer-actions specify 'rails-app'
type, so your mileage may vary).

Also, when developing the scripts, I was using a Rails app with a custom
PostgreSQL, so the use of the OpsWorks MySQL layer has not been tested, but
probably won't be affected (it will probably only limit the use of the
`ridoku-cli db` command set).

Once the Stack has been created and instances added using the OpsWorks GUI, 
you should be able to start using *ridoku* to make edits to your database and
environment information, as well as running recipes and commands on the stack.

Sadly, at this point, the OpsWorks GUI is still required.

## Custom Cookbooks

Currently, the Ridoku custom cookbooks are also required to ensure that the
environment is the same as is expected by a Heroku application.

## *ridoku*

```
  usage: ridoku [OPTIONS] command [command options]
    [--] is used to separate arguments from ridoku for each command
      e.g.,  'ridoku list-apps --help' display this help.
             'ridoku -- list-apps --help' displays list-apps help.

    commands:
      list
      config
      deploy
      domains
      db
      run
      cook

  Apps and Stacks:

  Amazon OpsWorks similarly to Heroku, but, because you own all the resources,
  you'll have to provide a bit more information than you do to Heroku in order
  for this commandline utility to assist.

    Stacks:  The technology stack to use for a particular type of application.

      Heroku probably has a similar structure internally, because they allow
      you to use any number of program Stacks (Rails, PHP, Python, Go, etc). 
      The difference is that now in OpsWorks you control the stack environment,
      where on Heroku you did not.

      If you have a stack configured, you can view pertinent information using
      
      $ ridoku-cli list:stacks

      This will display the stacks that are currently associated with your AWS
      account.  To 

      To set the specific stack to use:

      $ ridoku-cli --set-stack <stackname>

      To set a single run stack or override the default:

      $ ridoku-cli --stack <stackname> --app <appname> command...

    Apps:  The actual application which runs on the technology stack.

      This is what you have control over on Heroku.  You can customize the app
      domains, database information, environment, etc, on a per-application
      basis.  The same goes for OpsWorks.

      To set the default app to use:

      $ ridoku-cli --set-app <stackname>

      To set a specific run app or override the default:

      $ ridoku-cli --stack <stackname> --app <appname> command...
```

Other option that can used for other calls (specified in each help section,
e.g. `ridoku run:?`):

```
  --comment: add a comment to a deploy operation or recipe call
  --instance: select the instance to use for an operation (like a deploy or a recipe call) by 'hostname'
  --user: select the login user when executing a remote command or shell
  --layer: select the layer to act on by 'shortname'
```

## Future

I would like to get this to the point of a fully functional Heroku replacement.
Adding a standard `Rails` stack using the standard `LB -> Web Server*N <-> DB`
stack should be fairly easily accomplished, just needs to be added in.

If you have any issues when attempting to use this toolchain, please feel free
to submit a pull request.