
require 'ridoku/defaults'

module Ridoku
  class RailsDefaults < ClassProperties
    @required = {
      stack: {
        service_role_arn: :string,
        default_instance_profile_arn: :string,
        # attributes: Color: ?,
        custom_cookbooks_source: { ssh_key: :optional }
      },
      layer: {
        loadbalance: {
          attributes: { 
            haproxy_stats_password: :string,
            haproxy_stats_user: :string
          }
        },
        application: {},
        database: {}
      },
      app: {
        name: :string,
        shortname: :string,
        type: :string,

        ass_source: {
          url: :string,
          ssh_key: :optional
        },
        domains: :array
        attributes: {
          rails_env: :string
        }
      }
    }

    @defaults = {
      stack: {
        name: 'Ridoku-Rails',
        region: 'us-west-1',
        default_os: 'Ubuntu 12.04 LTS',
        hostname_theme: 'Legendary_creatures_from_Japan',
        default_availability_zone: 'us-west-1a',
        custom_json: '',
        configuration_manager: {
          name: 'Chef',
          version: '11.4'
        },
        use_custom_cookbooks:true,
        custom_cookbooks_source: {
          type: 'git',
          url: 'git@github.com:Protobit/chef-cookbooks.git',
          revision: 'master'
        },
        default_root_device_type: 'instance-store'
      },

      layer: [
        loadbalance: {
          standard: true,
          updates: true,
          type:'lb',
          attributes: {
            enable_haproxy_stats: 'true',
            haproxy_health_check_method: 'OPTIONS',
            haproxy_health_check_url: '/',
            haproxy_stats_url: '/haproxy?stats',
          },
          auto_assign_elastic_ips: true,
          auto_assign_public_ips: true,
          instance: {
            instance_type: 't1.micro',
            os: 'Ubuntu 12.04 LTS',
            availability_zone: 'us-west-1a',
            architecture: 'x86_64',
            root_device_type: 'instance-store',
            install_updates_on_boot: true
          }
        },
        application: {
          standard: true,
          updates: true,
          type:'rails-app',
          attributes: {
            bundler_version: '1.3.5',
            manage_bundler: 'true',
            rails_stack: 'nginx_unicorn',
            ruby_version:'1.9.3',
            rubygems_version:'2.1.5'
          },
          packages: ['imagemagick', 'libmagickwand-dev', 'nodejs'],
          auto_assign_elastic_ips: false,
          auto_assign_public_ips: true,
          custom_recipes:{
            configure: ['postgresql::ruby']
          },
          instance: {
            instance_type: 't1.micro',
            os: 'Ubuntu 12.04 LTS',
            availability_zone: 'us-west-1a',
            architecture: 'x86_64',
            root_device_type: 'instance-store',
            install_updates_on_boot: true
          }
        },
        database: {
          type: 'custom',
          name: 'Ridoku-Postgres',
          shortname: 'ridoku-postgres',
          attributes: {
          },
          auto_assign_elastic_ips:true,
          auto_assign_public_ips:true,
          custom_recipes:{
            setup: [],
            configure: [],
            deploy: [],
            undeploy: [],
            shutdown: []
          }
          instance: {
            instance_type: 't1.micro',
            os: 'Ubuntu 12.04 LTS',
            availability_zone: 'us-west-1a',
            architecture: 'x86_64',
            root_device_type: 'instance-store',
            install_updates_on_boot: true
          }
        }
      ],

      app: {
        app_source: {
          type: 'git',
          revision: 'master'
        },
        enable_ssl: false,
        attributes:{
          auto_bundle_on_deploy: true,
          document_root: 'public'
        },
      }
    }
  end
end