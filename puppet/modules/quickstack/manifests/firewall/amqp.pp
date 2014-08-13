class quickstack::firewall::amqp(
  $ports = ['5672'],
) {

  include quickstack::firewall::common

  Service['iptables'] ->
  firewall { '001 amqp incoming':
    proto  => 'tcp',
    dport  => $ports,
    action => 'accept',
  }
}
