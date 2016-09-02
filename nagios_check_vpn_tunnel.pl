#!/usr/bin/perl -w

# Check the status of a VPN tunnel for a remote Cisco based host to a specific peer.
#
# Nagios config example:
#   define command{
#     command_name check_remote_site_vpn
#     command_line $USER1$/check_remote_site_vpn $HOSTADDRESS$ $ARG1$ $ARG2$
#   }
#
# You might put something like this in your Nagios service definition:
#   check_command  check_asa_vpn!snmpstring!1.1.1.1

unless (($#ARGV == 2) or ($#ARGV == 3)) { print("usage:\tcheck_remote_site_vpn <IP address> <community> <peer IP> [friendlyname]\n"); exit(1);}

$IP = $ARGV[0];
$community = $ARGV[1];
$peerip = $ARGV[2];
if (defined($ARGV[3])) { $friendlyname = $ARGV[3]; }

$uptunnels = `/usr/local/bin/snmpwalk -v1 -c $community $IP 1.3.6.1.4.1.9.9.171.1.2.3.1.7`;

$state = "CRIT";
$msg = ": VPN tunnel to peer ".$peerip." is down. Failover has occurred.";
$output = "";

foreach (split("\n", $uptunnels)) {
        if ($_ =~ /SNMPv2-SMI::enterprises.9.9.171.1.2.3.1.7.\d+ = STRING: "$peerip"/) {
                $state = "OK";
                $msg = ": VPN tunnel to peer ".$peerip." is up.";
        }
}

print "" . $state . "" . $msg . "" . $output . "\n";

if ($state eq "OK") { exit 0;
} elsif ($state eq "WARN") { exit 1;
} elsif ($state eq "CRIT") { exit 2;
} else { #unknown!
        exit 3;
}
