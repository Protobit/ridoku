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
      # when 'list', nil, 'info'
      # when 'init'
      # when 'capture'
      # when 'delete', 'remove', 'rm'
      else
        $stderr.puts 'TODO: Implement backup capabilities (to S3).'
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
   backup[:list]   lists the stored database backups.
   backup:init     initialize backup capability (check S3 permissions, and
                   generate required S3 buckets).
   db:delete       remove specified backup by name.
   db:capture      capture a backup form the specified application database.
   db:url          get a download URL for the specified database backup.

EOF
    end
  end
end