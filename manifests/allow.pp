#  Installs and enables Ubuntu's "uncomplicated" firewall.
#
#  Be careful calling this class alone, it will by default enable ufw
# and disable all incoming traffic.
#
#
# @example when declaring the ufw class
#  ufw::allow { 'allow-ssh-from-all':
#    port => '22',
#  }
#
# @param direction (String) The first parameter for this class
# @param ensure (String) Enable of disable rule. default: present
# @param from (String) Ip address to allow access from. default: any
# @param ip (String) Ip address to allow access to. default: ''
# @param port (String) Port to act on. default: all
# @param proto (String) Protocol to use. default: tcp
# @param interface (String) Interface listen for connections to be on. default: ''
define ufw::allow(
  $direction ='IN',
  $ensure ='present',
  $from = 'any',
  $ip = '',
  $port = 'all',
  $proto = 'tcp',
  $interface = ''
) {
  validate_re($direction, 'IN|OUT')
  validate_re($ensure, 'absent|present')
  validate_re($proto, 'tcp|udp')
  validate_string($from,
    $ip,
    $port
  )

  $dir = $direction ? {
    'out'   => 'OUT',
    default => ''
  }

  if $ip == '' {
    $ipadr = pick($::ipaddress_eth0, $::ipaddress, 'any')
  } else {
    # Use $ip as ufw 'to' address when supplied
    $ipadr = $ip
  }

  $ipver = $ipadr ? {
    /:/     => 'v6',
    default => 'v4',
  }

  $ipadr_match = $ipadr ? {
    'any'   => $ipver ? {
      'v4' => 'Anywhere',
      'v6' => 'Anywhere \(v6\)',
    },
    default => $ipadr,
  }

  $from_match = $from ? {
    'any'   => $ipver ? {
      'v4' => 'Anywhere',
      'v6' => 'Anywhere \(v6\)',
    },
    default => $from,
  }

  $proto_match = $proto ? {
    'any'   => '',
    default => "/${proto}",
  }

  $from_proto_match = $from ? {
    'any'   => '',
    default => $proto_match,
  }

  $on_clause = $interface ? {
    ''   => '',
    default => "on ${interface}"
  }

  $grep_existing_rule = "${ipadr}:${port}" ? {
    'any:all'    => "grep -qE ' +ALLOW ${dir} +${from_match}$'",
    /[0-9]:all$/ => "grep -qE '^${ipadr}${proto_match} +ALLOW +${from_match}${from_proto_match}$'",
    /^any:[0-9]/ => "grep -qE '^${port}${proto_match} +ALLOW +${from_match}$'",
    default      => "grep -qE '^${ipadr} ${port}${proto_match} +ALLOW +${from_match}$'",
  }

  $rule = $port ? {
    'all'   => "allow ${dir} proto ${proto} ${on_clause} from ${from} to ${ipadr}",
    default => "allow ${dir} proto ${proto} ${on_clause} from ${from} to ${ipadr} port ${port}",
  }

  if $ensure == 'absent' {
    $command = "ufw delete ${rule}"
    $onlyif = "ufw status | ${grep_existing_rule}"

    exec { "ufw-delete-${proto}-from-${from}-to-${ipadr}-port-${port}":
      command  => $command,
      path     => '/usr/sbin:/bin:/usr/bin',
      provider => 'posix',
      onlyif   => $onlyif,
      require  => Exec['ufw-default-deny'],
      before   => Exec['ufw-enable'],
    }
  }
  else {
    $command = "ufw ${rule}"
    $unless  = "${ipadr}:${port}" ? {
      'any:all'    => "ufw status | grep -qE ' +ALLOW +${from_match}${proto_match}$'",
      #'any:all'    => "ufw status | grep -qE ' +ALLOW ${dir} +${from_match}( +.*)?$'",
      /[0-9]:all$/ => "ufw status | grep -qE '^${ipadr_match}${proto_match} +ALLOW +${from_match}${from_proto_match}( +.*)?$'",
      /^any:[0-9]/ => "ufw status | grep -qE '^${port}${proto_match} +ALLOW +${from_match}( +.*)?$'",
      default      => "ufw status | grep -qE '^${ipadr_match} ${port}${proto_match} +ALLOW +${from_match}( +.*)?$'",
    }

  exec { "ufw-allow-${direction}-${proto}-from-${from}-to-${ipadr}-port-${port}":
      command  => $command,
      path     => '/usr/sbin:/bin:/usr/bin',
      provider => 'posix',
      unless   => $unless,
      require  => Exec['ufw-default-deny'],
      before   => Exec['ufw-enable'],
    }
  }
}
