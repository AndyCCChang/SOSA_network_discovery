#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: sys_lib.pl
#  Author: Kylin Shih
#  Date: 2012/12/17
#  Description:
#    Sub-routines for system.
#########################################################################

require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/pro_lib.pl";

#########################################################
#  getResolv()
#  Input: -
#  Output: A hash contains information with keys: {"DNS1", "DNS2", "V6Enable", "V6DNS1", "V6DNS2"}
#	DNS1      string  IPV4 format IP of primary DNS server
#	DNS2      string  IPV4 format IP of secondary DNS server
#	V6Enable  string  "1" means enable ipv6's DNS or "0" means not
#	V6DNS1    string  IPV6 format IP of primary DNS server
#	V6DNS2    string  IPV6 format IP of secondary DNS server
#  Example: %dnslist = getResolv();
#########################################################
sub getResolv
{
	my %dnslist=();
	$dnslist{"DNS1"} = "";
	$dnslist{"DNS2"} = "";
	$dnslist{"V6DNS1"} = "";
	$dnslist{"V6DNS2"} = "";
	$dnslist{"V6Enable"} = "0";
	# copy source config to tmp file
	my $resolvin = gen_random_filename($CONF_RESOLV);
	system("$CP_CMD -f \"$CONF_RESOLV\" \"$resolvin\"");

	open(my $IN, $resolvin);
	while (<$IN>) {
		if (/nameserver\s+(\d+\.\d+\.\d+\.\d+)/) {
			if ($dnslist{"DNS1"} eq "") {
				$dnslist{"DNS1"} = $1;
			}
			else {
				$dnslist{"DNS2"} = $1;
			}
		}
		elsif ( /#\s*nameserver\s+(\S+\:\S+\:\S*)/ ) {
			if ($dnslist{"V6DNS1"} eq "") {
				$dnslist{"V6DNS1"} = $1;
			}
			else {
				$dnslist{"V6DNS2"} = $1;
			}
		}
		elsif ( /nameserver\s+(\S+\:\S+\:\S*)/ ) {
			if ($dnslist{"V6DNS1"} eq "") {
				$dnslist{"V6DNS1"} = $1;
			}
			else {
				$dnslist{"V6DNS2"} = $1;
			}
			$dnslist{"V6Enable"} = "1";
		}
	}
	close($IN);
	unlink($resolvin);
	return %dnslist;
}
#########################################################
#  setResolv()
#  Input:
#	DNS1      string  IPV4 format IP of primary DNS server
#	DNS2      string  IPV4 format IP of secondary DNS server
#	V6Enable  string  "1" means enable ipv6's DNS or "0" means not
#	V6DNS1    string  IPV6 format IP of primary DNS server
#	V6DNS2    string  IPV6 format IP of secondary DNS server
#  Output: 0 OK, others Fail
#########################################################
#Minging.Tsai. 2013/7/4. 
#Minging.Tsai. 2013/8/12. Remain the value if input is invalid.
sub setResolv{	
    my($DNS1, $DNS2, $V6Enable, $V6DNS1, $V6DNS2) = @_;
	#If input is invalid value, don't change.

	%dnslist = getResolv();#Get the origin setting.

    #print "DNS1=$DNS1, DNS2=$DNS2, V6Enable=$V6Enable, V6DNS1=$V6DNS1, V6DNS2=$V6DNS2\n";
    my $resolv_tmp = "/tmp/resolv.conf";
    #print "resolv_tmp=$resolv_tmp\n";
    open(my $OUT, ">$resolv_tmp");

    if($DNS1 ne "" && $DNS1 =~ /\d+\.\d+\.\d+\.\d+/){
        print $OUT "nameserver $DNS1\n";
	} else {
		print $OUT "nameserver $dnslist{\"DNS1\"}\n"  if($dnslist{"DNS1"} ne "");
	}
    if($DNS2 ne "" && $DNS2 =~ /\d+\.\d+\.\d+\.\d+/) {
		print $OUT "nameserver $DNS2\n";
	} else {
		print $OUT "nameserver $dnslist{\"DNS2\"}\n"  if($dnslist{"DNS2"} ne "");
	}


    if($V6Enable){
        if($V6DNS1 ne "" && $V6DNS1 =~ /\S+\:\S+\:\S*/){
            print $OUT "nameserver $V6DNS1\n";
        } else {
		    print $OUT "nameserver $dnslist{\"V6DNS1\"}\n"  if($dnslist{"V6DNS1"} ne "");
		}

        if($V6DNS2 ne "" && $V6DNS2 =~ /\S+\:\S+\:\S*/){
			print $OUT "nameserver $V6DNS2\n";
		} else {
		    print $OUT "nameserver $dnslist{\"V6DNS2\"}\n"  if($dnslist{"V6DNS2"} ne "");
		}

    }
    close($OUT);

    system("$CP_CMD -f $resolv_tmp \"$CONF_RESOLV\"");
    return $ret;

}
#########################################################
#  parse_netinfo()
#   Parse the network information of specific nas gateway.
#   The information will be put in 3 files which are /tmp/linkinfo_sn, /tmp/bondinfo_sn, /tmp/netinfo_sn
#  Input:
#   raw_file  string  Result file from nasfinder.
#   select_sn string  Serial number of the NAS gateway which need to parse the info.
#  Output: 0 OK, others Fail
#	Call by Helios_net_getgwnetinfo.pl
#########################################################
#Minging.Tsai. 2013/7/11. 
#Minging.Tsai. 2013/8/20.  Modify for interface select.
#Minging.Tsai. 2013/9/3.   Change for 10G ethernet port on eth4.
#Minging.Tsai. 2013/9/17.  Change for 10G * 2 as eth4, eth5 which always bond as bond1.
#Minging.Tsai. 2013/9/24.  Add NAS_VIP handle.
sub parse_netinfo {
	my($raw_file, $select_sn, $interface) = @_;	

	if(! -e $raw_file) {
		print "raw_file doesn't exist!";
		exit 1;
	}	
	my @netinfo_files = </tmp/netinfo_*>;
	my @bondinfo_files = </tmp/bondinfo_*>;
	my @linkinfo_files = </tmp/linkinfo_*>;
	unlink @netinfo_files;
	unlink @bondinfo_files;
	unlink @linkinfo_files;
	
	my %gwnetinfo;
	my @netinfo = ();
	my @inf = (x,x,x,x,x,x);
	my @mtu = (x,x,x,x,x,x);
	my @speed = (x,x,x,x,x,x);
	my @proto = (x,x,x,x,x,x);
	my @ip = (x,x,x,x,x,x);
	my @nm = (x,x,x,x,x,x);
	my @gw = (x,x,x,x,x,x);
	my @dns1 = (x,x,x,x,x,x);
	my @dns2 = (x,x,x,x,x,x);
	my @ip6_proto = (x,x,x,x,x,x);
	my @ip6_addr = (x,xx,x,x,x);
	my @ip6_prefixlen;
	my @ip6_gw = (x,x,x,x,x,x);
	my @ip6_dns1 = (x,x,x,x,x,x);
	my @ip6_dns2 = (x,x,x,x,x,x);
	my @bond_group;
	my @bond_mode;
	my $nonbond_group="";
	my $sn = "";
	my $hostname = "";
	my $product = "";
	$bond_mode[0]=6;
	$bond_mode[1]=6;
#	$bond_mode[2]=6;
#	$bond_mode[3]=6;

	open(my $IN_RAW,"<$raw_file");
	while(<$IN_RAW>) {
		$current_line = $_;		
		if($current_line =~ /&\S+&(\S+)&\S+&\S+&&&/) {
			#Just get the info of specific serial number.
			next if($1 ne $select_sn);
		}
		if($current_line =~ /([^\&]+)&([^\&]+)&([^\&]+)&[^\&]+&[^\&]+&[^\&]+&[^\&]+&&&/ ) {

			$hostname = $1;
			print "hostname = $hostname\n";
			$mac = $2;
			print "mac = $mac\n";
			$linkport = $3;
			print "linkport = $linkport\n";
			# write the linkinfo
			open(my $OUT_LINK,">>/tmp/linkinfo_".$select_sn);
			print $OUT_LINK "$linkport=$mac\n";
			close($OUT_LINK);		
		}
		if(! -e "/tmp/netinfo_".$select_sn && $current_line =~ /&&&(\S+)&&(\S+)&&(\S+)&&(\S+)&&(\S+)&&(\S+)&&/ ) {	#Minging.Tsai. 2013/9/2. For 10G port * 2.
			#next if(-e "/tmp/netinfo_".$select_sn);
			$product = $hostname;	
			$netinfo[0] = $1;
			$netinfo[1] = $2;
			$netinfo[2] = $3;
			$netinfo[3] = $4;
			$netinfo[4] = $5;#Minging.Tsai. 2013/9/2. For 10G port.
			$netinfo[5] = $6;#Minging.Tsai. 2013/9/2. For 10G port.
			$bond_group[0]="";
			$bond_group[1]="";
			$nonbond_group="";			
			
			for($i=0; $i<=$#netinfo; $i++) {
								#&eth0&1500&1000&ip&192.168.207.116&255.255.255.0&192.168.207.1&192.168.207.2&192.168.202.108
				if( $netinfo[$i] =~ /(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)/ ) {								
#					print "netinfo[$i] = $netinfo[$i]\n";				
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
					} elsif($i =~ /[0-3]/) {
						if($nonbond_group eq "") {#
							$nonbond_group="eth".$i;
						}
					}	
				}
			}
			# write the bondinfo
			open(my $OUT_BOND,">/tmp/bondinfo_".$select_sn);
			print $OUT_BOND "bond0=$bond_group[0]\n";
			print "bond0=$bond_group[0]\n";
			print $OUT_BOND "bond0_mode=$bond_mode[0]\n";
			print "bond0_mode=$bond_mode[0]\n";
			print $OUT_BOND "bond1=$bond_group[1]\n";
			print $OUT_BOND "bond1_mode=$bond_mode[1]\n";
			print $OUT_BOND "nonbond=$nonbond_group\n";
			close($OUT_BOND);
			# write the netinfo
			open(my $OUT_NET,">/tmp/netinfo_".$select_sn);
			print $OUT_NET "hostname=$hostname\n";			
			for($i=0; $i<=$#netinfo; $i++) {
				print $OUT_NET "mtu[$i]=$mtu[$i]\n";
				print $OUT_NET "speed[$i]=$speed[$i]\n";
				print $OUT_NET "proto[$i]=$proto[$i]\n";
				print $OUT_NET "ip[$i]=$ip[$i]\n";
				print $OUT_NET "netmask[$i]=$nm[$i]\n";
				print $OUT_NET "gateway[$i]=$gw[$i]\n";
				print $OUT_NET "dns1[$i]=$dns1[$i]\n";
				print $OUT_NET "dns2[$i]=$dns2[$i]\n";
				print $OUT_NET "ipv6_proto[$i]=$ip6_proto[$i]\n";
				print $OUT_NET "ipv6_ip[$i]=$ip6_addr[$i]\n";
				print $OUT_NET "ipv6_prefixlen[$i]=$ip6_prefixlen[$i]\n";
				print $OUT_NET "ipv6_gateway[$i]=$ip6_gw[$i]\n";
				print $OUT_NET "ipv6_dns1[$i]=$ip6_dns1[$i]\n";
				print $OUT_NET "ipv6_dns2[$i]=$ip6_dns2[$i]\n";	
				
			}			
			close($OUT_NET);

			if($interface != -1) {
				#Get 1 interface.
				$gwnetinfo{bond0} = $bond_group[0];
				$gwnetinfo{bond0_mode} = $bond_mode[0];
				$gwnetinfo{bond1} = $bond_group[1];
				$gwnetinfo{bond1_mode} = $bond_mode[1];
				$gwnetinfo{hostname} = $hostname;

				$gwnetinfo{mtu} = $mtu[$interface];
				$gwnetinfo{speed} = $speed[$interface];
				$gwnetinfo{proto} = $proto[$interface];
				$gwnetinfo{ip} = $ip[$interface];
				$gwnetinfo{netmask} = $nm[$interface];
				$gwnetinfo{gateway} = $gw[$interface];
				$gwnetinfo{dns1} = $dns1[$interface];
				$gwnetinfo{dns2} = $dns2[$interface];
				$gwnetinfo{ipv6_proto} = $ip6_proto[$interface];
				$gwnetinfo{ipv6_ip} = $ip6_addr[$interface];
				$gwnetinfo{ipv6_gateway} = $ip6_gw[$interface];
				$gwnetinfo{ipv6_dns1} = $ip6_dns1[$interface];
				$gwnetinfo{ipv6_dns2} = $ip6_dns1[$interface];
			} else {#$interface == -1 means get all info
				for($i = 0; $i < 6; $i++) {
					$gwnetinfo[$i]{bond0} = $bond_group[0];
					$gwnetinfo[$1]{bond0_mode} = $bond_mode[0];

	                $gwnetinfo[$i]{bond1} = $bond_group[1];
					$gwnetinfo[$i]{bond1_mode} = $bond_mode[1];

					$gwnetinfo[$i]{hostname} = $hostname;

					$gwnetinfo[$i]{mtu} = $mtu[$i];
					$gwnetinfo[$i]{speed} = $speed[$i];
					$gwnetinfo[$i]{proto} = $proto[$i];
					$gwnetinfo[$i]{ip} = $ip[$i];
					$gwnetinfo[$i]{netmask} = $nm[$i];
					$gwnetinfo[$i]{gateway} = $gw[$i];
					$gwnetinfo[$i]{dns1} = $dns1[$i];
					$gwnetinfo[$i]{dns2} = $dns2[$i];
					$gwnetinfo[$i]{ipv6_proto} = $ip6_proto[$i];
					$gwnetinfo[$i]{ipv6_ip} = $ip6_addr[$i];
					$gwnetinfo[$i]{ipv6_gateway} = $ip6_gw[$i];
					$gwnetinfo[$i]{ipv6_dns1} = $ip6_dns1[$i];
					$gwnetinfo[$i]{ipv6_dns2} = $ip6_dns1[$i];
				}
			}
		}
	}
	close($IN_RAW);
	return %gwnetinfo;
}
#########################################################
#  parse_nasgwinfo()
#  Input:
#   raw_file  string  Result file from nasfinder.
#  Output: 0 OK, others Fail
#########################################################
#Minging.Tsai. 2013/7/11. 
#Get all of the serial number, ip ,and hostname of nas gateway.
#Minging.Tsai. 2013/8/13. Add Helios joining procedure.
#Minging.Tsai. 2013/9/24.  Add NAS_VIP handle.
sub parse_nasgwinfo {
	my($raw_file) = @_;	
	if(! -e $raw_file) {
		print "raw_file doesn't exist!";
		exit -1;
	}		
	#unlink("/tmp/nasgwinfo");
	my %gwinfo = ();
	
	my $nas_number = 0;
	#open(my $OUT_NASGW,">>/tmp/nasgwinfo"); #There is no need to output file now.
	open(my $IN_RAW,"<$raw_file");
	while(<$IN_RAW>) {
		my $current_sn = "";
		my $had_record = 0;
#		if( /^[^\&]+&.+&(\S+)&\S+&\S+&&&.+/) {
		if( /&([^\&]+)&[^\&]+&[^\&]+&&&.+/) {
			$current_sn = $1;
			for($i = 0; $i < $nas_number; $i++) {
				if($current_sn eq $gwinfo[$i]{sn}) {
					#print "NAS has in record\n";
					$had_record = 1;
					last;
				}
			}
		}
		#Skip the line with same info.
		next if($had_record != 0);
		
		if( /^([^\&]+)&.+&([^\&]+)&([^\&]+)&&&(.+)/) {
			my $hostname = $1;
			my $Helios = $2;
			my $NAS_VIP = $3;#Minging.Tsai. 2013/9/24.
			my $sub_line = $4;

			#print "$line";
			$gwinfo[$nas_number]{sn} = $current_sn;
			$gwinfo[$nas_number]{hostname} = $hostname;
			$gwinfo[$nas_number]{Helios} = $Helios; #Minging.Tsai. 2013/8/13
			$gwinfo[$nas_number]{NAS_VIP} = $NAS_VIP; #Minging.Tsai. 2013/9/24
			if($sub_line =~ /(\d+\.\d+\.\d+\.\d+)/o) {
				#Get IP		
				$gwinfo[$nas_number]{ip} = $1;
				print "IP= $gwinfo[$nas_number]{ip}\n";
			}				
			#print $OUT_NASGW "$current_sn\n";
			#print "current_sn=$sn{$nas_number}\n";
			$nas_number++;
		}
	}	
	close($IN_RAW);
	#close($OUT_NASGW);
	return %gwinfo;
}
# This part is from VR2000 which its network setting goes with I2.
#########################################################
#  setResolv()
#  Input:
#	DNS1      string  IPV4 format IP of primary DNS server
#	DNS2      string  IPV4 format IP of secondary DNS server
#	V6Enable  string  "1" means enable ipv6's DNS or "0" means not
#	V6DNS1    string  IPV6 format IP of primary DNS server
#	V6DNS2    string  IPV6 format IP of secondary DNS server
#  Output: 0 OK, others Fail
#########################################################
#modified by fred to call i2 set the dns	2013.04.16
#sub setResolv{
	#	CLI not support secondary dns now
#	my($DNS1, $DNS2, $V6Enable, $V6DNS1, $V6DNS2) = @_;
#	
#	my $ret=0;
#	if($DNS1 ne "" && $DNS1 =~ /\d+\.\d+\.\d+\.\d+/){
#		$ret+=system("$I2ARYTOOL_CMD net -a mod -f ipv4 -s \\\"primarydns=$DNS1\\\"");
#	}
#	if($V6Enable){
#		if($V6DNS1 ne "" && $V6DNS1 =~ /\S+\:\S+\:\S*/){
#			$ret+=system("$I2ARYTOOL_CMD net -a mod -f ipv6 -s \\\"primarydns=$DNS1\\\"");
#		}
#	}
#	return $ret;
#}

sub getnetmask
{
	my($ip,$netmask)=@_;
	my $mask1=$mask2=$mask3=$mask4="";
	my $ip1=$ip2=$ip3=$ip4="";
	
	if($netmask =~/(\d+).(\d+).(\d+).(\d+)/){
		$mask1=$1;
		$mask2=$2;
		$mask3=$3;
		$mask4=$4;
	}
	if($ip =~/(\d+).(\d+).(\d+).(\d+)/){
		$ip1=$1;
		$ip2=$2;
		$ip3=$3;
		$ip4=$4;
	}
	if($mask3 == 255){
		return "$ip1.$ip2.$ip3.0/24";
	}elsif($mask2 == 255){
		return "$ip1.$ip2.0.0/16";
	}elsif($mask1 == 255){
		return "$ip1.0.0.0/8";
	}
}

sub getnetdevip{
	my($dev) = @_;
	my $IP="";
	open(my $IN,"ifconfig $dev |");
	while(<$IN>){
		if(/inet addr:(\d+\.\d+\.\d+\.\d+)/){
			$IP=$1;
		}
	}
	close($IN);
	return $IP;
}
sub setiproutetablebond1{
	my ($vip)=@_;
	my $dev = "bond1";
	$ip = getnetdevip("bond1");
	open(my $IN,"ip rule |");
	while(<$IN>){
		if(/from\s+(\S+)\s+lookup\s+(\S+)/){
			print "$1 $2\n";	
			if($2 eq $dev . "_t"){
				system("ip rule del from $1 lookup $2");
			}
		}	
	}
	close($IN);
	system("ip rule add from $ip table " . $dev . "_t");
	if($vip ne ""){
		system("iptables -t mangle -F");
		system("iptables -t mangle -A PREROUTING -d $vip/32 -p tcp -j MARK --set-mark 2");
		system("iptables -t mangle -A PREROUTING -d $vip/32 -p udp -j MARK --set-mark 2");
		system("ip rule add from $vip table " . $dev . "_t");
	}
}
sub setiproutetablebond0{
	my ($dev,$ip,$netmask,$gateway)=@_;
	my $maskstr = getnetmask($ip,$netmask);
	my @rule;
	open(my $IN,"ip rule |");
	while(<$IN>){
		if(/from\s+(\S+)\s+lookup\s+(\S+)/){
			print "$1 $2\n";	
			if($2 eq $dev . "_t"){
				system("ip rule del from $1 lookup $2");
			}
		}	
	}
	close($IN);
	system("ip rule add from $ip table " . $dev . "_t");
	push @rule,"$maskstr dev $dev";
	push @rule,"default via $gateway dev $dev";
	setiproutetablerule($dev . "_t" , @rule);
}
sub setiproutetable{
	my ($dev,$ip,$netmask,$gateway)=@_;
	my $maskstr = getnetmask($ip,$netmask);
	my @rule;
	open(my $IN,"ip rule |");
	while(<$IN>){
		if(/from\s+(\S+)\s+lookup\s+(\S+)/){
			print "$1 $2\n";	
			if($2 eq $dev . "_t"){
				system("ip rule del from $1 lookup $2");
			}
		}	
	}
	close($IN);
	system("ip rule add from $ip table " . $dev . "_t");
	push @rule,"$maskstr dev $dev";
	push @rule,"default via $gateway dev $dev";
	setiproutetablerule($dev . "_t" , @rule);
}

sub setiproutetablerule{
	my ($table,@newrule)=@_;
	open(my $IN,"ip route list table $table |");
	my @tablerule = <$IN>;
	close($IN);
	foreach my $rule(@tablerule){
			chomp($rule);
			print "ip route del " . $rule . "table " . $table . "\n";
			system("ip route del " . $rule . "table " . $table);
	}
	foreach $rule(@newrule){
			print "ip route add " . $rule . " table " . $table . "\n";
			system("ip route add " . $rule . " table " . $table);
	}
}

sub setdirectroute{
	my($directip)=@_;
	system("ip route add to " . $directip . "dev bond0");
}

sub deldirectroute{
	my($directip) =@_;
	system("ip route del to " . $directip . "dev bond0");
}

sub PingBond1DefGW {
	my $status = 0;
	my $def_gw_ip = "";
	open(CMD, "ip route list |");
	read(CMD, $buf, 9999);
	close(CMD);
	if( $buf =~ /default via (\S+) dev bond1/ ) {
		$def_gw_ip = $1;
	}

	if( $def_gw_ip ne "" ) {
		for($i = 0; $i < 2; $i++) {
			system("ping -w 1 $def_gw_ip -I bond1");
			if( $? == 0 ) {
				$status = 1;
				last;
			}
		}
	}
	else {
		$status = -1;
	}

	return $status;
}

return 1;  # this is required.
