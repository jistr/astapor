class quickstack::neutron::firewall::gre (
) {
  include quickstack::firewall::common

  Service['iptables'] ->
  firewall { '002 gre':
    proto  => 'gre',
    action => 'accept',
  }
}
