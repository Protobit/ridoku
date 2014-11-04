

module Ridoku
  class ConfigWizard
    attr_accessor :fields

    def initialize
      self.fields = {
        service_role_arn: :arn_string,
        instance_profile_arn: :arn_string,
        ssh_key: :path
      }
    end

    def run
      $stdout.puts $stdout.colorize(ConfigWizard.help_text, :bold)

      $stdout.puts "Do you wish to run the wizard now? [#{$stdout.colorize('Y', :bold)}|n]"
      res = $stdin.gets
      if res.match(%r(^[Nn]))
        Base.config[:local_init] = true
        Base.save_config(::RUNCOM)
        exit 1
      end

      sra_info = <<-EOF
    Service Role ARN is used to access OpsWorks and issue commands on your
    behalf.  No suitable role was found.

    Please enter the appropriate Role used to issue commands on OpsWorks.
    Leave the field blank to attempt to generate one or to refresh from account
    credentials. 's' or 'skip' if you wish to use existing values.

    #{$stdout.colorize('Current Service ARN:', [:white, :bold])} #{$stdout.colorize(Base.config[:service_arn], :green)}
    EOF
      inst_info = <<-EOF
    Instance Profile ARN is used to for each instance created for OpsWorks.

    Please enter the appropriate default Role used for instance profiles.
    Leave the field blank to attempt to generate one or to refresh from account
    credentials. 's' or 'skip' if you wish to use existing values.

    #{$stdout.colorize('Current Instance ARN:', [:white, :bold])} #{$stdout.colorize(Base.config[:instance_arn], :green)}
    EOF
      info = {
        service_role_arn: sra_info,
        instance_profile_arn: inst_info
      }

      ConfigWizard.fetch_input(Base.config, fields, info)

      case Base.config[:service_role_arn]
      when ''
        Base.config.delete(:service_arn)
        Base.configure_service_roles
      when 's', 'skip'
      else
        Base.config[:service_arn] = Base.config[:service_role_arn]
      end

      case Base.config[:instance_profile_arn]
      when ''
        Base.config.delete(:instance_arn)
        Base.configure_instance_roles
      when 's', 'skip'
      else
        Base.config[:instance_arn] = Base.config[:instance_profile_arn]
      end

      Base.config[:local_init] = true
      Base.save_config(::RUNCOM)

      $stdout.puts 'Updating required Security Groups'
      Base.update_pg_security_groups_in_all_regions

      $stdout.puts 'Configuration complete.'
      exit 0
    end
    protected

    class << self

      def help_text
        help = <<-EOF
Configuration Wizard:

In order to get ridoku configured with your OpsWorks account, Ridoku must 
collect pertinent required info. The wizard can be run at any time after the
first with the command line option of `--wizard`.

Values to be configured:
  ssh_key: 
    Path to the SSH key to be used for git repositories
    (cook books, apps, etc).  It is recommended that this be generated
    separately from your personal SSH keys so that they can be revoked
    effecting other logins.

  service_role_arn:
    If a valid service_role_arn cannot be found, Ridoku will attempt to
    generate one for you.  If you've already used OpsWorks, Ridoku should be
    able to find the necessary Roles for you.

  instance_role_arn:
    If a valid instance_role_arn cannot be found, Ridoku will attempt to
    generate one for you.  If you've already used OpsWorks, Ridoku should be
    able to find the necessary Roles for you.
        EOF
      end

      def fetch_input(output, required = {}, info = {})
        info ||= {}
        info.merge!({
          ssh_key: <<-EOF
    Key files (such as SSH keys) should be provided by file path.  In the case of
    GIT repository SSH keys (custom cookbooks, application respository), these 
    should be to the private keys.  I recommend generating keys specifically for 
    each use, so that the keys can be easily tracked and removed if necessary,
    without requiring you replace your keys on every machine you access.
    Enter 's' or 'skip' if you wish to keep the currently configured value.
    EOF
        })

        recurse_required(required, output, info)
      end

      protected

      # Recurse through required hash to collected all necessary information.
      def recurse_required(req, user, info, buffer = '')
        req.each do |k,v|
          if v.is_a?(Hash)
            buffer += info_for(k, info)
            buffer += "In #{$stdout.colorize(k, :bold)}:"
            recurse_required(v, user[k] ||= {}, info, buffer)
            buffer = ''
          else
            next if user[k]
            $stdout.puts '-'*80
            $stdout.puts buffer if buffer.length > 0
            info_block = info_for(k, info)
            $stdout.puts info_block if info_block.length > 0
            $stdout.puts "For #{$stdout.colorize(k, :bold)} (#{$stdout.colorize(v, :red)}):"
            get_response(user, k, v)
          end
        end
      end

      # Handle getting the response from the user and validating input.
      def get_response(user, key, value)
        done = false
        while !done
          begin
            val = validate_response(key, value, $stdin.gets.chomp)
            user[key] = val unless val == :skip
            done = true
          rescue ArgumentError => e
            $stdout.puts e.to_s
            $stdout.puts 'Retry?'
            res = $stdin.gets
            done = (res.match(/^(Y|y)/) == nil)
          end
        end
      end

      # Validate input is as expected.
      def validate_response(key, expect, value)
        return :skip if value.match(%r(s|skip))

        case key
        when :ssh_key
          value.gsub!(%r(^~), ENV['HOME']) if value.match(%r(^~))

          fail ArgumentError.new('Invalid input provided.') unless
            File.exists?(value) || value == ''
        end

        case expect
        when :arn_string
          fail ArgumentError.new('Invalid ARN provided.') unless
            value.match(/^.*:.*:.*:.*:([0-9]+):.*$||/)
        when :array
          value = value.split(%r([^\\](:|\|)))
        end

        value
      end

      # Print warning info associated with a particular attributes.
      def info_for(key, info)
        return $stdout.colorize(info[key], :bold) if info.key?(key)
        ''
      end
    end
  end
end