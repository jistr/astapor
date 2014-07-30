# Class for nodes running any OpenStack services
class quickstack::openstack_common(
  $create_basic_fw_rules = true,
) {

  include quickstack::firewall::common
  if (str2bool($::selinux) and $::operatingsystem != "Fedora") {
      package{ 'openstack-selinux':
          ensure => present, }
  }

  # for any Fedora, and for Enterprise Linux > 6
  if ($::operatingsystem == 'Fedora' or
      ($::operatingsystem != 'Fedora' and $::operatingsystemmajrelease > 6)) {
    # Uninstall firewalld since everything uses iptables for now
    # and recreate the basic rules
    package { 'firewalld':
      ensure => "absent",
    }
  }
  if (str2bool_i($create_basic_fw_rules)) {
    Package['firewalld'] ->
    firewall { '000 icmp':
      proto  => 'icmp',
      action => 'accept',
    } ->
    firewall { '000 related and established':
      proto   => 'all',
      ctstate => ['RELATED', 'ESTABLISHED'],
      action  => 'accept',
    } ->
    firewall { '000 loopback':
      proto   => 'all',
      iniface => 'lo',
      action  => 'accept',
    } ->
    firewall { '010 ssh':
      proto  => 'tcp',
      ctstate => ['NEW'],
      dport  => 22,
      action => 'accept',
    } ->
    firewall { '999 reject all':
      proto  => 'all',
      action => 'reject',
      reject => 'icmp-host-prohibited',
    } ->
    firewall { '999 fwd reject all':
      chain  => 'FORWARD',
      proto  => 'all',
      action => 'reject',
      reject => 'icmp-host-prohibited',
    }
  }

  service { "auditd":
    ensure => "running",
    enable => true,
  }
}
