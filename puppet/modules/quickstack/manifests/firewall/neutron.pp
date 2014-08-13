class quickstack::firewall::neutron (
  $ports = ['9696'],
  $proto = 'tcp',
) {

  include quickstack::firewall::common

  Service['iptables'] ->
  firewall { '001 neutron incoming':
    proto  => $proto,
    dport  => $ports,
    action => 'accept',
  }
}
