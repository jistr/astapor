class quickstack::neutron::firewall::vxlan (
  $port = 4789,
) {
  include quickstack::firewall::common

  Service['iptables'] ->
  firewall { '002 vxlan udp':
    proto  => 'udp',
    dport  => ["${port}"],
    action => 'accept',
  }
}
