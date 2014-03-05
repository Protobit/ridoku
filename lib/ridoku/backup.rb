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
        restore
      when 'delete', 'remove', 'rm'
        remove
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

    def print_db_help
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
      puts 'TODO: List S3 Backup Bucket contents...'
    end

    def init
      puts 'TODO: Configure S3 bucket...'
    end

    def capture
      recipe_data = {
        backup: {
          databases: Base.config[:app].downcase.split(','),
          dump: {
            type: 's3',
            region: 'us-west-1',
            bucket: Base.config[:backup_bucket] || 'database-backups'
          }
        }
      }
    end

    def restore
      puts 'TODO: kick off restore recipe'
    end

    def remove
      puts 'TODO: remove specified s3 file.'
    end
  end
end
