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
        capture
      when 'restore'
        restore(ARGV.shift)
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
        Base.custom_json['deploy'][Base.config[:app].downcase]['database']
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

EOF
    end

    def list
      bucket_exists!

      s3 = AWS::S3.new

      bucket = s3.buckets[Base.config[:backup_bucket]]

      # hack: couldn't find how to get an object count...
      objects = 0

      bucket.objects.each do |obj|
        $stdout.puts "#{$stdout.colorize(obj.key, :bold)}, "\
          "#{nice_bytes(obj.content_length)} bytes, "\
          "#{obj.content_type.length > 0 ?
              obj.content_type :
              '(content-type unspecified)'}"
        objects += 1
      end

      if objects > 0
        $stdout.puts "#{objects} objects found."
      else
        $stdout.puts "There are no objects in the specified backup bucket!"
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

    def capture
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

      Base.fetch_instance
      Base.instances.select! { |inst| inst[:status] == 'online' }
      instance_ids = Base.instances.map { |inst| inst[:instance_id] }

      command = Base.execute_recipes(Base.app[:app_id], instance_ids,
        'Capturing application DB backup.', ['postgresql::backup_database'])

      Base.run_command(command)
    end

    def restore(sub)
      bucket_exists!
      object_exists!(sub, 'restore')
      puts 'TODO: kick off restore recipe'
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

    def fail_object_not_found
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
