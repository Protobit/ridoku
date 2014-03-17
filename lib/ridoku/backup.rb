#
# Command: backup
# Description: List/Modify the current apps database backups
#  backup - lists the database backups
#

require 'ridoku/base'

module Ridoku
  register :backup

  class Backup < Base
    attr_accessor :dbase

    def run
      cline = Base.config[:command]
      current = cline.shift
      command = cline.shift
      sub = cline.shift

      case command
      when 'list', nil, 'info'
        list
      when 'init'
        init
      when 'capture'
        capture(sub)
      when 'restore'
        restore(sub, ARGV.shift)
      when 'delete', 'remove', 'rm'
        remove(ARGV.shift)
      else
        print_backup_help
      end
    end

    protected

    def load_database
      Base.fetch_stack
      Base.fetch_layer
      self.dbase =
        Base.custom_json['deploy'][Base.config[:app]]['database']
    end

    def print_backup_help
      $stderr.puts <<-EOF
Command: backup

List/Modify the current app's database backups.
   backup[:list]      lists the stored database backups.
   backup:init        initialize backup capability (check S3 permissions, and
                      generate required S3 buckets).
   backup:rm <name>   remove specified backup by name.
   backup:capture     capture a backup form the specified application database.
   backup:url <name>  get a download URL for the specified database backup.

   Development:
   backup:capture:local <pg_dump path> 
    Capture a backup locally using the apps config.  Include the path the
    desired 'pg_dump' command.  Version 9.2 or above is required.
   backup:restore:local <pg_restore path> 
    Restore a backup locally using the apps config.  Include the path the
    desired 'pg_restore' command.  Version 9.2 or above is required.

EOF
    end

    def objects_from_bucket(bucket)
      s3 = AWS::S3.new

      bucket = s3.buckets[bucket]

      # hack: couldn't find how to get an object count...
      objects = 0

      bucket.objects.map do |obj|
        { key: obj.key, size: obj.content_length, type: obj.content_type }
      end
    end

    def object_list_to_hash(list)
      final = {}
      max = 0

      list.each do |obj|
        comp = obj[:key].match(
          %r(^(.*)-([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2}).sqd$)
        )

        max = obj[:key].length if obj[:key].length > max

        unless comp.nil?
          app = comp[1]
          final[app] ||= []
          obj[:app] = app
          obj[:date] = "#{comp[3]}/#{comp[4]}/#{comp[2]} #{comp[5]}:#{comp[6]}"
          final[app] << obj
        end
      end

      [ final, max ]
    end

    def pspace(str, max)
      str + ' ' * (max - str.length)
    end

    def list
      bucket_exists!

      list = objects_from_bucket(Base.config[:backup_bucket])
      app_hash, max = object_list_to_hash(list)

      app_hash.each do |key, value|
        $stdout.puts "#{$stdout.colorize(key, :green)}:"
        value.each do |obj|
          $stdout.puts "  #{pspace(obj[:key], max)}  "\
            "#{obj[:date]}\t#{obj[:type]}"
        end
      end
    end

    def init
      fail_undefined_bucket! if Base.config[:backup_bucket].nil?

      s3 = AWS::S3.new
      bucket = s3.buckets[Base.config[:backup_bucket]]
      $stdout.puts "Checking for '#{$stdout.colorize(bucket.name, :bold)}' "\
        'S3 Buckets...'
      if bucket.exists?
        $stdout.puts "Bucket exists!"
      else
        $stdout.puts "Bucket does not exist.  Generating..."
        begin
          bucket = s3.buckets.create(Base.config[:backup_bucket],
            acl: :bucket_owner_full_control)
        rescue => e
          $stderr.puts "Oops! Something went wrong when trying to create your bucket!"
          raise e
        end

        $stdout.puts 'Bucket created successfully!'
        $stdout.puts "#{$stdout.colorize(bucket.name, [:bold, :green])}: owner read/write."
      end
    end

    def bucket_exists!
      # Fail if bucket not set
      fail_undefined_bucket! if Base.config[:backup_bucket].nil?

      s3 = AWS::S3.new
      bucket = s3.buckets[Base.config[:backup_bucket]]
      $stdout.print "Checking for '#{$stdout.colorize(bucket.name, :bold)}' "\
        'S3 Buckets... '

      fail_uninitialized_bucket! unless bucket.exists?

      $stdout.puts $stdout.colorize('Found!', :green)
    end

    def object_exists!(sub, action)
      fail_undefined_object!(action) if sub.nil? || !sub.present?

      s3 = AWS::S3.new
      bucket = s3.buckets[Base.config[:backup_bucket]]
      $stdout.print "Checking for '#{$stdout.colorize(sub, :bold)}' "\
        'in bucket... '

      fail_object_not_found! unless bucket.objects[sub].exists?

      $stdout.puts $stdout.colorize('Found!', :green)
    end

    def dump_local()
      load_database

      command = ARGV.shift

      unless m = `#{command} --version`.match(/(9[.][23]([.][0-9]+)?)/)
        $stderr.puts "Invalid pg_dump version #{m[1]}."
        return
      end

      backup_file = "#{Base.config[:app]}-"\
        "#{Time.now.utc.strftime("%Y%m%d%H%M%S")}.sql"

      $stdout.puts "pg_dump version: #{$stdout.colorize(m[1], :green)}"
      $stdout.puts "Creating backup file: #{backup_file}"

      # Add PGPASSWORD to the environment.
      ENV['PGPASSWORD'] = dbase['password']

      system(["#{command}",
        "-Fc",
        "-h #{dbase['host']}",
        "-U #{dbase['username']}",
        "-p #{dbase['port']}",
        "#{dbase['database']}",
        "> #{backup_file}"].join(' '))

      $stdout.puts $stdout.colorize("pg_dump complete.", :green)
      $stdout.puts "File size: #{::File.size(backup_file)}"
      ENV['PGPASSWORD'] = nil
    end

    def capture(opt)
      return dump_local if opt == 'local'

      bucket_exists!

      recipe_data = {
        backup: {
          databases: Base.config[:app].downcase.split(','),
          dump: {
            type: 's3',
            region: 'us-west-1',
            bucket: Base.config[:backup_bucket]
          }
        }
      }

      Base.fetch_app
      Base.fetch_instance
      instances = Base.get_instances_for_layer('postgresql')
      instance_ids = instances.map { |inst| inst[:instance_id] }

      command = Base.execute_recipes(Base.app[:app_id], instance_ids,
        'Capturing application DB backup.', ['s3',
          'postgresql::backup_database'], recipe_data)

      Base.run_command(command)
    end

    def restore_local(file)
      load_database

      command = ARGV.shift

      unless m = `#{command} --version`.match(/(9[.][23]([.][0-9]+)?)/)
        $stderr.puts "Invalid pg_restore version #{m[1]}."
        return
      end

      $stdout.puts "pg_restore version: #{$stdout.colorize(m[1], :green)}"
      $stdout.puts "Using backup file: #{file}"

      # Add PGPASSWORD to the environment.
      ENV['PGPASSWORD'] = dbase['password']

      system(["#{command}",
        "--clean",
        "#{'--single-transaction' unless Base.config[:force]}",
        "-h #{dbase['host']}",
        "-U #{dbase['username']}",
        "-p #{dbase['port']}",
        "-d #{dbase['database']}",
        "#{file}"].join(' '))

      $stdout.puts $stdout.colorize("pg_restore complete.", :green)
      $stdout.puts "File size: #{::File.size(backup_file)}"
      ENV['PGPASSWORD'] = nil
    end

    def restore(sub, arg)
      return restore_local(file) if sub == 'local'

      bucket_exists!
      object_exists!(arg, 'restore')
      $stdout.puts 'Are you sure you want to restore this database dump? [yes/N]'
      res = $stdin.gets.chomp

      if res.present? && res == 'yes'
        recipe_data = {
          backup: {
            databases: Base.config[:app].downcase.split(','),
            force: Base.config[:force] || false,
            dump: {
              type: 's3',
              region: 'us-west-1',
              bucket: Base.config[:backup_bucket],
              key: arg
            }
          }
        }

        Base.fetch_app
        Base.fetch_instance
        layer_ids = Base.get_layer_ids('postgresql')

        Base.instances.select! do |inst|
          next false unless inst[:status] == 'online'
          next layer_ids.each do |id|
            break true if inst[:layer_ids].include?(id)
          end || false
        end

        instance_ids = Base.instances.map { |inst| inst[:instance_id] }

        command = Base.execute_recipes(Base.app[:app_id], instance_ids,
          'Restoring application DB backup.', ['s3',
            'postgresql::restore_database'], recipe_data)

        Base.run_command(command)
      else
        $stdout.puts 'Aborting.'
      end
    end

    def remove(sub)
      bucket_exists!
      object_exists!(sub, 'remove')

      $stdout.puts 'Are you sure you want to delete this file? [yes/N]'
      res = $stdin.gets.chomp

      if res.present? && res == 'yes'
        s3 = AWS::S3.new
        bucket = s3.buckets[Base.config[:backup_bucket]]
        object = bucket.objects[sub]
        object.delete

        $stdout.puts 'Request object deleted.'
      else
        $stdout.puts 'Aborting.'
      end
    end

    protected

    def fail_undefined_bucket!
      fail ArgumentError.new(<<EOF
Your Backup S3 bucket name is undefined.
Please set it by passing in --set-backup-bucket followed by the desired bucket
name.

Example:
$ ridoku --set-backup-bucket zv1ns-database-backups

EOF
      )
    end

    def fail_uninitialized_bucket!
        # Fail if bucket doesn't exist.
      fail ArgumentError.new(<<EOF

The specified S3 backup bucket does not yet exist.  Please create it manually,
or by running ([] represents optional arguments):

$ ridoku backup:init [--backup-bucket <bucket name>]

EOF
      )
    end

    def fail_undefined_object!(action)
      # Fail if object name not set
      fail ArgumentError.new(<<EOF
The specified backup (#{Base.config[:backup_bucket]}/#{sub}) doesn't exist!

Example:
$ ridoku backup:#{action} <name>

EOF
        )
    end

    def fail_object_not_found!
        # Fail if bucket doesn't exist.
      fail ArgumentError.new(<<EOF

The specified S3 backup object does not yet exist.  Please create it manually,
or by running ([] represents optional arguments):

$ ridoku backup:capture [--backup-bucket <bucket name> --app <app name>]

EOF
      )
    end
  end
end
