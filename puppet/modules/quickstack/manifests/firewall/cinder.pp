class quickstack::firewall::cinder (
  $port = '8776',
) {

  include quickstack::firewall::common

  Service['iptables'] ->
  firewall { '001 cinder incoming':
    proto  => 'tcp',
    dport  => ["$port"],
    action => 'accept',
  }
}
