# TODO
# refine iptable rules, their probably giving access to the public
#

class quickstack::controller (
  $admin_email                = $quickstack::params::admin_email,
  $admin_password             = $quickstack::params::admin_password,
  $cinder_db_password         = $quickstack::params::cinder_db_password,
  $cinder_user_password       = $quickstack::params::cinder_user_password,
  $glance_db_password         = $quickstack::params::glance_db_password,
  $glance_user_password       = $quickstack::params::glance_user_password,
  $horizon_secret_key         = $quickstack::params::horizon_secret_key,
  $keystone_admin_token       = $quickstack::params::keystone_admin_token,
  $keystone_db_password       = $quickstack::params::keystone_db_password,
  $mysql_root_password        = $quickstack::params::mysql_root_password,
  $nova_db_password           = $quickstack::params::nova_db_password,
  $nova_user_password         = $quickstack::params::nova_user_password,
  $pacemaker_priv_floating_ip = $quickstack::params::pacemaker_priv_floating_ip,
  $pacemaker_pub_floating_ip  = $quickstack::params::pacemaker_pub_floating_ip,
  $verbose                    = $quickstack::params::verbose
) inherits quickstack::params {

    #pacemaker::corosync { 'quickstack': }

    #pacemaker::corosync::node { '10.100.0.2': }
    #pacemaker::corosync::node { '10.100.0.3': }

    #pacemaker::resources::ip { '8.21.28.222':
    #    address => '8.21.28.222',
    #}
    #pacemaker::resources::ip { '10.100.0.222':
    #    address => '10.100.0.222',
    #}

    #pacemaker::resources::lsb { 'qpidd': }

    #pacemaker::stonith::ipmilan { $ipmi_address:
    #    address  => $ipmi_address,
    #    user     => $ipmi_user,
    #    password => $ipmi_pass,
    #    hostlist => $ipmi_host_list,
    #}

    class {'openstack::db::mysql':
        mysql_root_password  => $mysql_root_password,
        keystone_db_password => $keystone_db_password,
        glance_db_password   => $glance_db_password,
        nova_db_password     => $nova_db_password,
        cinder_db_password   => $cinder_db_password,
        neutron_db_password  => '',

        # MySQL
        mysql_bind_address     => '0.0.0.0',
        mysql_account_security => true,

        # Cinder
        cinder                 => false,

        # neutron
        neutron                => false,

        allowed_hosts          => '%',
        enabled                => true,
    }

    class {'qpid::server':
        auth => "no"
    }

    class {'openstack::keystone':
        db_host               => $pacemaker_priv_floating_ip,
        db_password           => $keystone_db_password,
        admin_token           => $keystone_admin_token,
        admin_email           => $admin_email,
        admin_password        => $admin_password,
        glance_user_password  => $glance_user_password,
        nova_user_password    => $nova_user_password,
        cinder_user_password  => $cinder_user_password,
        neutron_user_password => "",
        public_address        => $pacemaker_pub_floating_ip,
        admin_address         => $pacemaker_priv_floating_ip,
        internal_address      => $pacemaker_priv_floating_ip,
        neutron               => false,
        cinder                => false,
        enabled               => true,
        require               => Class['openstack::db::mysql'],
    }

    class { 'swift::keystone::auth':
        password => $swift_admin_password,
        address  => $pacemaker_priv_floating_ip,
    }

    class {'openstack::glance':
        db_host               => $pacemaker_priv_floating_ip,
        user_password  => $glance_user_password,
        db_password    => $glance_db_password,
        require               => Class['openstack::db::mysql'],
    }

    # Configure Nova
    class { 'nova':
        sql_connection     => "mysql://nova:${nova_db_password}@${pacemaker_priv_floating_ip}/nova",
        image_service      => 'nova.image.glance.GlanceImageService',
        glance_api_servers => "http://${pacemaker_priv_floating_ip}:9292/v1",
        rpc_backend        => 'nova.openstack.common.rpc.impl_qpid',
        verbose            => $verbose,
        require            => Class['openstack::db::mysql', 'qpid::server'],
    }

    class { 'nova::api':
        enabled           => true,
        admin_password    => $nova_user_password,
        auth_host         => $pacemaker_priv_floating_ip,
    }

    nova_config {
        'DEFAULT/auto_assign_floating_ip': value => 'True';
        'DEFAULT/multi_host':              value => 'True';
        'DEFAULT/force_dhcp_release':      value => 'False';
    }

    class { [ 'nova::scheduler', 'nova::cert', 'nova::consoleauth', 'nova::conductor' ]:
        enabled => true,
    }

    class { 'nova::vncproxy':
        host    => '0.0.0.0',
        enabled => true,
    }

    package {'horizon-packages':
        name   => ['python-memcached', 'python-netaddr'],
        notify => Class['horizon'],
    }

    file {'/etc/httpd/conf.d/rootredirect.conf':
        ensure  => present,
        content => 'RedirectMatch ^/$ /dashboard/',
        notify  => File['/etc/httpd/conf.d/openstack-dashboard.conf'],
    }

    class {'horizon':
        secret_key    => $horizon_secret_key,
        keystone_host => $pacemaker_priv_floating_ip,
    }

    class {'memcached':}

# Double definition - This seems to have appeared with Puppet 3.x
#   class {'apache':}
#   class {'apache::mod::wsgi':}
#   file { '/etc/httpd/conf.d/openstack-dashboard.conf':}

    firewall { '001 controller incoming':
        proto    => 'tcp',
        # need to refine this list
        dport    => ['80', '3306', '5000', '35357', '5672', '8773', '8774', '8775', '8776', '9292', '6080'],
        action   => 'accept',
    }

    if ($::selinux != "false"){
      selboolean{'httpd_can_network_connect':
          value => on,
          persistent => true,
      }
    }
}
