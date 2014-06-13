class quickstack::pacemaker::cinder(
  $db_name                = 'cinder',
  $db_user                = 'cinder',

  $volume                 = false,
  $backend_eqlx           = false,
  $backend_eqlx_name      = 'eqlx_backend',
  $backend_glusterfs      = false,
  $backend_glusterfs_name = 'glusterfs_backend',
  $backend_iscsi          = false,
  $backend_iscsi_name     = 'iscsi_backend',
  $backend_nfs            = false,
  $backend_nfs_name       = 'nfs_backend',
  $backend_rbd            = false,
  $backend_rbd_name       = 'rbd_backend',

  $multiple_backends      = false,

  $glusterfs_shares       = [],

  $nfs_shares             = [],
  $nfs_mount_options      = undef,

  $san_ip                 = '',
  $san_login              = 'grpadmin',
  $san_password           = '',
  $san_thin_provision     = false,
  $eqlx_group_name        = 'group-0',
  $eqlx_pool              = 'default',
  $eqlx_use_chap          = false,
  $eqlx_chap_login        = 'chapadmin',
  $eqlx_chap_password     = '',

  $rbd_pool               = 'volumes',
  $rbd_ceph_conf          = '/etc/ceph/ceph.conf',
  $rbd_flatten_volume_from_snapshot
                          = false,
  $rbd_max_clone_depth    = '5',
  $rbd_user               = 'cinder',
  $rbd_secret_uuid        = '',

  $db_ssl                 = false,
  $db_ssl_ca              = undef,

  $rpc_backend            = 'cinder.openstack.common.rpc.impl_qpid',
  $qpid_heartbeat         = '60',

  $use_syslog             = false,
  $log_facility           = 'LOG_USER',

  $enabled                = true,
  $debug                  = false,
  $verbose                = false,
) {

  include ::quickstack::pacemaker::common

  if (map_params('include_cinder') == 'true' and map_params("db_is_ready")) {

    include ::quickstack::pacemaker::qpid

    $cinder_user_password = map_params("cinder_user_password")
    $cinder_private_vip   = map_params("cinder_private_vip")
    $pcmk_cinder_group    = map_params("cinder_group")
    $db_host              = map_params("db_vip")
    $db_password          = map_params("cinder_db_password")
    $glance_host          = map_params("glance_admin_vip")
    $keystone_host        = map_params("keystone_admin_vip")
    $qpid_host            = map_params("qpid_vip")
    $qpid_port            = map_params("qpid_port")
    $qpid_username        = map_params("qpid_username")
    $qpid_password        = map_params("qpid_password")

    Exec['i-am-cinder-vip-OR-cinder-is-up-on-vip'] -> Exec['cinder-manage db_sync']
    if (map_params('include_mysql') == 'true') {
      if str2bool_i("$hamysql_is_running") {
        Exec['mysql-has-users'] -> Exec['i-am-cinder-vip-OR-cinder-is-up-on-vip']
      }
    }
    if (map_params('include_keystone') == 'true') {
      Exec['all-keystone-nodes-are-up'] -> Exec['i-am-cinder-vip-OR-cinder-is-up-on-vip']
    }
    if (map_params('include_swift') == 'true') {
      Exec['all-swift-nodes-are-up'] -> Exec['i-am-cinder-vip-OR-cinder-is-up-on-vip']
    }
    if (map_params('include_glance') == 'true') {
      Exec['all-glance-nodes-are-up'] -> Exec['i-am-cinder-vip-OR-cinder-is-up-on-vip']
    }
    if (map_params('include_nova') == 'true') {
      Exec['all-nova-nodes-are-up'] -> Exec['i-am-cinder-vip-OR-cinder-is-up-on-vip']
    }

    Class['::quickstack::pacemaker::qpid']
    ->
    # assuming openstack-cinder-api and openstack-cinder-scheduler
    # always have same vip's for now
    quickstack::pacemaker::vips { "$pcmk_cinder_group":
      public_vip  => map_params("cinder_public_vip"),
      private_vip => map_params("cinder_private_vip"),
      admin_vip   => map_params("cinder_admin_vip"),
    }
    ->
    exec {"i-am-cinder-vip-OR-cinder-is-up-on-vip":
      timeout => 3600,
      tries => 360,
      try_sleep => 10,
      command => "/tmp/ha-all-in-one-util.bash i_am_vip $cinder_private_vip || /tmp/ha-all-in-one-util.bash property_exists cinder",
      unless => "/tmp/ha-all-in-one-util.bash i_am_vip $cinder_private_vip || /tmp/ha-all-in-one-util.bash property_exists cinder",
    }
    ->
    class {'::quickstack::cinder':
      user_password  => $cinder_user_password,
      bind_host      => map_params('local_bind_addr'),
      db_host        => $db_host,
      db_name        => $db_name,
      db_user        => $db_user,
      db_password    => $db_password,
      db_ssl         => $db_ssl,
      db_ssl_ca      => $db_ssl_ca,
      glance_host    => $glance_host,
      keystone_host  => $keystone_host,
      rpc_backend    => $rpc_backend,
      amqp_host      => $qpid_host,
      amqp_port      => $qpid_port,
      amqp_username  => $qpid_username,
      amqp_password  => $qpid_password,
      qpid_heartbeat => $qpid_heartbeat,
      use_syslog     => $use_syslog,
      log_facility   => $log_facility,
      enabled        => $enabled,
      debug          => $debug,
      verbose        => $verbose,
    }

    Class['::quickstack::cinder']
    ->
    class {"::quickstack::load_balancer::cinder":
      frontend_pub_host    => map_params("cinder_public_vip"),
      frontend_priv_host   => map_params("cinder_private_vip"),
      frontend_admin_host  => map_params("cinder_admin_vip"),
      backend_server_names => map_params("lb_backend_server_names"),
      backend_server_addrs => map_params("lb_backend_server_addrs"),
    }
    ->
    exec {"pcs-cinder-server-set-up":
      command => "/usr/sbin/pcs property set cinder=running --force",
    } ->
    exec {"pcs-cinder-server-set-up-on-this-node":
      command => "/tmp/ha-all-in-one-util.bash update_my_node_property cinder"
    } ->
    exec {"all-cinder-nodes-are-up":
      timeout   => 3600,
      tries     => 360,
      try_sleep => 10,
      command   => "/tmp/ha-all-in-one-util.bash all_members_include cinder",
    }
    ->
    quickstack::pacemaker::resource::service {'openstack-cinder-api':
      group => "$pcmk_cinder_group",
      clone => true,
    }
    ->
    quickstack::pacemaker::resource::service {'openstack-cinder-scheduler':
      group => "$pcmk_cinder_group",
      clone => true,
    }

    if str2bool_i("$volume") {
      Class['::quickstack::cinder']
      ->
      class {'::quickstack::cinder_volume':
        backend_glusterfs      => $backend_glusterfs,
        backend_glusterfs_name => $backend_glusterfs_name,
        backend_iscsi          => $backend_iscsi,
        backend_iscsi_name     => $backend_iscsi_name,
        backend_nfs            => $backend_nfs,
        backend_nfs_name       => $backend_nfs_name,
        backend_eqlx           => $backend_eqlx,
        backend_eqlx_name      => $backend_eqlx_name,
        backend_rbd            => $backend_rbd,
        backend_rbd_name       => $backend_rbd_name,
        multiple_backends      => $multiple_backends,
        iscsi_bind_addr        => map_params('local_bind_addr'),
        glusterfs_shares       => $glusterfs_shares,
        nfs_shares             => $nfs_shares,
        nfs_mount_options      => $nfs_mount_options,
        san_ip                 => $san_ip,
        san_login              => $san_login,
        san_password           => $san_password,
        san_thin_provision     => $san_thin_provision,
        eqlx_group_name        => $eqlx_group_name,
        eqlx_pool              => $eqlx_pool,
        eqlx_use_chap          => $eqlx_use_chap,
        eqlx_chap_login        => $eqlx_chap_login,
        eqlx_chap_password     => $eqlx_chap_password,
        rbd_pool               => $rbd_pool,
        rbd_ceph_conf          => $rbd_ceph_conf,
        rbd_flatten_volume_from_snapshot
                               => $rbd_flatten_volume_from_snapshot,
        rbd_max_clone_depth    => $rbd_max_clone_depth,
        rbd_user               => $rbd_user,
        rbd_secret_uuid        => $rbd_secret_uuid,
      }
      ->
      Exec['pcs-cinder-server-set-up']

      Exec['all-cinder-nodes-are-up']
      ->
      quickstack::pacemaker::resource::service {'openstack-cinder-volume':
        group => "$pcmk_cinder_group",
        clone => true,
      }
    }
  }
}
