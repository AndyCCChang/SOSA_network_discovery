#!/usr/bin/perl

my @netinfo_files = </tmp/netinfo_*>;
my @bondinfo_files = </tmp/bondinfo_*>;
my @linkinfo_files = </tmp/linkinfo_*>;
unlink @netinfo_files;
unlink @bondinfo_files;
unlink @linkinfo_files;

my @netinfo;
my @inf;
my @mtu;
my @speed;
my @proto;
my @ip;
my @nm;
my @gw;
my @dns1;
my @dns2;
my @ip6_proto;
my @ip6_addr;
my @ip6_prefixlen;
my @ip6_gw;
my @ip6_dns1;
my @ip6_dns2;
my @bond_group;
my @bond_mode;
my $nonbond_group="";

$bond_mode[0]=6;
$bond_mode[1]=6;
$bond_mode[2]=6;
$bond_mode[3]=6;

if($ARGV[0] ne "") {
	$raw_file = $ARGV[0];
} else {
	$raw_file = "/tmp/nasfinder.log";
}
open(IN,"<$raw_file");
while(<IN>) {
#	if( /(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&&&(\S+)&&(\S+)&&/ ) {
	if( /(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&&&(\S+)&&(\S+)&&(\S+)&&(\S+)&&/ ) {
		$hostname = $1;
		$mac = $2;
		$linkport = $3;
		$product = $4;
		$sn = $5;
		$netinfo[0] = $6;
		$netinfo[1] = $7;
		$netinfo[2] = $8;
		$netinfo[3] = $9;
		for($i=0; $i<=$#netinfo; $i++) {
			if( $netinfo[$i] =~ /(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)/ ) {


				$inf[$i] = $1;
				$mtu[$i] = $2;
				$speed[$i] = $3;
				$proto[$i] = $4;
				$ip[$i] = $5;
				$nm[$i] = $6;
				$gw[$i] = $7;
				$dns1[$i] = $8;
				$dns2[$i] = $9;
				if($10 ne "x") {
					$ip6_proto[$i] = "dhcp"		if($10 eq "dhcp6");
					$ip6_proto[$i] = "ip"		if($10 eq "ip6");
				}
				if($11 ne "x") {
					if( $11 =~ /(\S+)\/(\d+)/ ) {
						$ip6_addr[$i] = $1;
						$ip6_prefixlen[$i] = $2;
					} else {
						$ip6_addr[$i] = $11;
						$ip6_prefixlen[$i] = 64;
					}
				}
				if($12 ne "x") {
					$ip6_gw[$i] = $12;
				}
				if($13 ne "x") {
					$ip6_dns1[$i] = $13;
				}
				if($14 ne "x") {
					$ip6_dns2[$i] = $14;
				}
				if($inf[$i] =~ /^bond(\d+)m(\d+)/) {
					$bond_mode[$1]=$2;
					if($bond_group[$1] eq "") {
						$bond_group[$1]="eth".$i;
					} else {
						$bond_group[$1]=$bond_group[$1]." eth".$i;
					}
				} else {
					if($nonbond_group eq "") {
						$nonbond_group="eth".$i;
					} else {
						$nonbond_group=$nonbond_group." eth".$i;
					}
				}	
			}
		}
		# write the linkinfo
		open(OUT,">>/tmp/linkinfo_".$sn);
		print OUT "$linkport=$mac\n";
		close(OUT);
		# write the bondinfo
		if ( ! -e "/tmp/bondinfo_".$sn) {
			open(OUT,">/tmp/bondinfo_".$sn);
			print OUT "bond0=$bond_group[0]\n";
			print OUT "bond0_mode=$bond_mode[0]\n";
			print OUT "bond1=$bond_group[1]\n";
			print OUT "bond1_mode=$bond_mode[1]\n";
			print OUT "nonbond=$nonbond_group\n";
			close(OUT);
		}
		# write the netinfo
		if ( ! -e "/tmp/netinfo_".$sn) {
			open(OUT,">/tmp/netinfo_".$sn);
			print OUT "hostname=$hostname\n";
			for($i=0; $i<=$#netinfo; $i++) {
				print OUT "mtu[$i]=$mtu[$i]\n";
				print OUT "speed[$i]=$speed[$i]\n";
				print OUT "proto[$i]=$proto[$i]\n";
				print OUT "ip[$i]=$ip[$i]\n";
				print OUT "netmask[$i]=$nm[$i]\n";
				print OUT "gateway[$i]=$gw[$i]\n";
				print OUT "dns1[$i]=$dns1[$i]\n";
				print OUT "dns2[$i]=$dns2[$i]\n";
				print OUT "ipv6_proto[$i]=$ip6_proto[$i]\n";
				print OUT "ipv6_ip[$i]=$ip6_addr[$i]\n";
				print OUT "ipv6_prefixlen[$i]=$ip6_prefixlen[$i]\n";
				print OUT "ipv6_gateway[$i]=$ip6_gw[$i]\n";
				print OUT "ipv6_dns1[$i]=$ip6_dns1[$i]\n";
				print OUT "ipv6_dns2[$i]=$ip6_dns2[$i]\n";
			}
			close(OUT);
		}
	}
}
close(IN);

exit;
