class quickstack::firewall::load_balancer (
  $ports = ['81'],
  $proto = 'tcp',
){

  include quickstack::firewall::common

  Service['iptables'] ->
  firewall { '001 load balancer incoming':
    proto  => $proto,
    dport  => $ports,
    action => 'accept',
  }
}
