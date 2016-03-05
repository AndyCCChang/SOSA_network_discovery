#!/usr/bin/perl
use Fcntl qw(:flock);
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/net_lib.pl";
require "/nasapp/perl/lib/sys_lib.pl";
require "/nasapp/perl/lib/log_db_lib.pl";
#Minging.Tsai. 2013/9/24.   Add NAS_VIP handle.
#Minging.Tsai. 2013/10/3.   Add NAS Status handle.
#Minging.Tsai. 2013/10/15.	Encrypt the serial number make it not look like a MAC addr.
#Minging.Tsai. 2013/10/22.	Add Helios_Join_sn handle.
#Minging.Tsai. 2013/10/23.  Prevent net_getnetinfo.pl been activated too ofter to ruin /tmp/c_netinfo_multi.
#Minging.Tsai. 2013/12/15   Called by alert_agent now.

#Check counter of net_getnetinfo.pl
open(my $IN, "ps ax | grep -c \"/usr/bin/perl /nasapp/perl/util/net_util_getnet.pl\" |");
while(<$IN>) {
	if (/(\d+)/) {
		$process_count = $1;
		print "process_count=$process_count\n";
		if ($process_count >= 4) {
			print "[net_util_getnet]: program execute over once!!!!\n";
			exit 0;
		}
	}
}
close($IN);

# SN
# We may not get the SN on nas gateway, so here we use MAC of eth0 to be serial number.
my $eth0_mac = "";
open(my $IN, "ethtool -e eth0 offset 0x0 length 6 |");
while(<$IN>) {
	if(/\S+\s+(\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+)/) {
		$eth0_mac = $1;
		$eth0_mac =~ s/ //g;
	}
}
close($IN);

print "eth0_mac = $eth0_mac\n";
#Encrypt the serial number.
#$SN = MAC_encrypt($eth0_mac);
$SN = $eth0_mac;
#print "Encrypted serial_number = $SN\n";
print "Serial_number = $SN\n";

if(-e "/nasdata/config/etc/sn") {
	my $node_sn = `cat /nasdata/config/etc/sn`;
	chomp($node_sn);
	if($node_sn ne $SN) {#This shouldn't happen since the eth0 MAC and sn shouldn't change.
		system("echo \"$SN\" >/nasdata/config/etc/sn");
		naslog($LOG_NAS_CONFIG, $LOG_ERROR, "01", "NAS gateway serial number changed from $node_sn to $SN. It shouldn't happen.");
	}
} else {
	system("echo \"$SN\" >/nasdata/config/etc/sn");
}

#Minging.Tsai. 2014/7/24.
#Get NASGW SSN
my $SSN = $SN;#To prevent the NASGW doesn't have SSN.
my $tmp_SSN = `/usr/local/sbin/sys_ssn.sh get`;
print "tmp_SSN1=$tmp_SSN\n";
$tmp_SSN =~ s/ //g;
print "tmp_SSN2=$tmp_SSN\n";
$tmp_SSN =~ /\"(\S+)\"/;
print "SSN3=$SSN\n";
$SSN = $1 if($1 ne "");

my $serial_number = $SN . "|" . $SSN;
print "serial_number=$serial_number\n";
# Product Name
open(my $IN,"</etc/config/product");
while(<$IN>) {
	if ( /^NAME\s*=\s*(\S+)/ ) {
		$prdname = $1;
	}
	elsif ( /^BASE\s*=\s*(\S+)/ ) {
		$basename = $1;
	}
}
close($IN);

# Hostname
$hostname = `/bin/hostname`;
print "SOSA hostname=$hostname \n";
chomp($hostname);

my @inf = ();
my @bond_mode;
my @ip = (x,x,x,x,x,x);
my @netmask = (x,x,x,x,x,x);
my @gw = (x,x,x,x,x,x);

$ETH_PORT_NUM = 6;

for($i=0; $i < $ETH_PORT_NUM; $i++) {
	my $config_file="/etc/config/eth".$i;

    $ifcon = `$IFCONFIG_CMD eth$i`;
	if ( $ifcon eq "" ) {
		# Minging.Tsai. 2013/9/2. This NAS gateway doesn't have this port.
		$inf[$i] = "NA";
	}
	next if($inf[$i] eq "NA");

	open(my $IN,"<$config_file");
	while(<$IN>){
		if ( /^BOND=(\S+)/ ) {
			if($1 eq "NO") {
				$inf[$i] = "eth".$i;
			}
		}
		elsif ( $inf[$i] ne "eth".$i && /^BOND_GROUP=(\d+)/ ) {
			$inf[$i] = "bond".$1;
		}
		elsif ( /^MODE=(\S+)/ ) {
			$bond_mode[$i] = $1;
		}
	}
	close($IN);
	# BOND=YES without BOND_GROUP
}

# IP & Netmask & Gateway
my $bond1_gw = "0.0.0.0";
for($i=0; $i < $ETH_PORT_NUM; $i++) {
	next if($inf[$i] eq "NA");
	$ifconfig = `$IFCONFIG_CMD $inf[$i]|$GREP_CMD inet`;
	if ( $ifconfig =~ /inet\s+addr:(\S+)\s+Bcast:\S+\s+Mask:(\S+)/ ) {
		$ip[$i] = $1;
		print "ip[$i]=$ip[$i]\n";
		$netmask[$i] = $2;
	}
#    print "$ROUTE_CMD -n -A inet|$GREP_CMD UG|$GREP_CMD $inf[$i]\n";
#	$route = `$ROUTE_CMD -n -A inet|$GREP_CMD UG|$GREP_CMD $inf[$i]`;
	$cmd = "ip route list table ".$inf[$i]."_t";
	print "$cmd\n";
	$route = `$cmd`;
	#if ( $route =~ /(\S+)\s+(\S+)\s+(\S+)\s+UG/ ) {
    if ( $route =~ /default via (\S+) dev bond/ ) {
		$gw[$i] = $1;
		$bond1_gw = $1 if($inf[$i] eq "bond1");
		print "\$gw[$i]=$gw[$i]\n";
    } else {
		$gw[$i] = "0.0.0.0";
	}
}
for($i=0; $i < $ETH_PORT_NUM; $i++) {
	next if($inf[$i] eq "NA");#Minging.Tsai. 2013/9/16.
	if($inf[$i] =~ /^bond/) {
		$inf[$i]=$inf[$i]."m".$bond_mode[$i];
	}
}

#Minging.Tsai. 2013/8/13.
#Get Helios join information.
my $Helios_Join = "none";
my $Helios_Join_sn = "none";
my $NAS_VIP = "none";
my $NAS_GW = "none";
my $CLUSTER_SN = "none";
open(my $IN, "<$JOIN_CONF");
while(<$IN>) {
	if(/HELIOS_JOIN=(\S+)/) {
		$Helios_Join = $1;
	} elsif(/HELIOS_JOIN_SN=(\S+)/) {
		$Helios_Join_sn = $1;
	} elsif(/VIP=(\S+)/) {
		$NAS_VIP = $1;
	} elsif(/GW=(\S+)/) {
		$NAS_GW = $1;
	} elsif(/CLUSTER_SN=(\S+)/) {
		$CLUSTER_SN = $1;
	}
}
close($IN);

$NAS_VIP = $NAS_VIP . "|" . $CLUSTER_SN;

#Minging.Tsai. 2013/9/26.
#Get firmware version.
my $FW_VER = "0.0.0.0";
open(my $FW_VER_IN, "</etc/sysconfig/rev");
while(<$FW_VER_IN>) {
	if(/(\S+)/) {
		$FW_VER = $1;
	}
}
close($FW_VER_IN);

#Minging.Tsai. 2014/1/20.
#Get BIOS version.
my $bios_ver = `dmidecode -s bios-version`;
my $bios_date = `dmidecode -s bios-release-date`;
chomp($bios_ver);
chomp($bios_date);
$bios_date =~ s/\///g;
$FW_VER = $FW_VER . "|" . $bios_ver . "_" . $bios_date;

my $Status = "";#The Status will now indicate not only the NAS gateway status but also link status.
#11 bits of Status.
#0~5 eth[0-5]
#6~7 bond[0-1]
#8~9 fc[0-1]
#10  Status

#Get the Link info.
my @eth_info = get_eth_status();
for($i = 0; $i < 6; $i++) {
    $speed[$i] = ($eth_info[$i]{"LINK"} eq 0 || $eth_info[$i]{"LINK"} eq "")? 0 : $eth_info[$i]{'SPEED'};

    print "speed[$i]=$speed[$i]\n";

	$Status .= $eth_info[$i]{'LINK'} ne "" ? $eth_info[$i]{'LINK'} : 0;#In case we cannot get info.
}
$Status .= $eth_info[6]{'LINK'};#bond0
my $bond1_gw_reachable = 1;
if($eth_info[7]{'LINK'}) {
	if($bond1_gw ne "0.0.0.0") {#Do the ping gw check if it is not 0.0.0.0
		$bond1_gw_reachable = PingBond1DefGW();
	}
	$Status .= $bond1_gw_reachable ? 1 : 3;#bond1 is online, report 3 if gw has been setup but not reachable.
} else {
	$Status .= 0;#bond1 
}

if($eth_info[6]{'LINK'} == 0) {
	print "Ethernet bond0 is not connected.\n";
	write_status_detail("Eth_bond0", 2);
} else {
	print "Ethernet bond0 is connected.\n";
	write_status_detail("Eth_bond0", 0);
}

if($eth_info[7]{'LINK'} == 0) {
	print "Ethernet bond1 is not connected.\n";
	write_status_detail("Eth_bond1", 2);
} elsif($bond1_gw_reachable == 0) {
	print "Ethernet bond1 is connected but cannot reach gw ip.\n";
	write_status_detail("Eth_bond1", 1);
} else {
	print "Ethernet bond1 is connected.\n";
	write_status_detail("Eth_bond1", 0);
} 

#Get FC information.

@fc_info = get_fc_status();
@FCWWN = ();
$Status .= $fc_info[0]{"LINK"} eq Online ? 1 : 0;#Convert Online/Linkdown to 0/1
$Status .= $fc_info[1]{"LINK"} eq Online ? 1 : 0;#Convert Online/Linkdown to 0/1

if($fc_info[0]{"LINK"} ne Online && $fc_info[1]{"LINK"} ne Online) {
	print "Both fiber channels are offline.\n";
	write_status_detail("Fiber", 2);
} else {
	print "One or more fiber channel is online.\n";
	write_status_detail("Fiber", 0);
}


$FCWWN[0] = $fc_info[0]{"WWPN"};
$FCWWN[1] = $fc_info[1]{"WWPN"};
$FCWWN[0] = "0FCWWN0" if($FCWWN[0] eq "");
$FCWWN[1] = "0FCWWN1" if($FCWWN[1] eq "");
print "FCWWN[0]=$FCWWN[0]\n";
print "FCWWN[1]=$FCWWN[1]\n";


#Minging.Tsai. 2013/10/3.
#Get NAS Status.
my $sys_status = 0;
open(my $STATUS_IN, "<$CONF_SYS_STATUS");
while(<$STATUS_IN>) {
    if(/(\d)/) {
	    $sys_status = $1;
		last;
    }
}
close($Status_IN);

$Status .= $sys_status;
open(my $IN, "/tmp/sys_status_detail");
while(<$IN>) {
	if(/Protocol=(\d+)/) {
		$sys_sta_Protocol = $1;
	} elsif(/Enclosure=(\d+)/) {
		$sys_sta_Enclosure = $1;
	} elsif(/Mount=(\d+)/) {
		$sys_sta_Mount = $1;
	} elsif(/Upgrade=(\d+)/) {
		$sys_sta_Upgrade = $1;
	} elsif(/Raid=(\d+)/) {
		$sys_sta_Raid = $1;
	} elsif(/Syncing=(\d+)/) {
		$sys_sta_Syncing = $1;
	} elsif(/Eth_bond0=(\d+)/) {
		$sys_sta_Eth_bond0 = $1;
	} elsif(/Eth_bond1=(\d+)/) {
		$sys_sta_Eth_bond1 = $1;
	} elsif(/Fiber=(\d+)/) {
		$sys_sta_Fiber = $1;
	} elsif(/Domain=(\d+)/) {
		$sys_sta_Domain = $1;
	} elsif(/Cluster=(\d+)/) {
		$sys_sta_Cluster = $1;
	}
}
close($IN);
$Status .= $sys_sta_Protocol;
$Status .= $sys_sta_Enclosure;
$Status .= $sys_sta_Mount;
$Status .= $sys_sta_Upgrade;
$Status .= $sys_sta_Raid;
$Status .= $sys_sta_Syncing;
$Status .= $sys_sta_Eth_bond0;
$Status .= $sys_sta_Eth_bond1;
$Status .= $sys_sta_Fiber;
$Status .= $sys_sta_Domain;
$Status .= $sys_sta_Cluster;

print "Status=$Status\n";

#Minging.Tsai. 2013/10/16.
#Get NAS GW model.
my $model_name = "NAS_GW_scu1";
if($inf[4] ne "NA") {
	$model_name = "NAS_GW_scu2"
}


open(LOCKFILE, ">/tmp/getnet_lock") or die "/tmp/getnet_lock: $!";
flock(LOCKFILE, LOCK_EX) or die "flock() failed for /tmp/getnet_lock: $!";

open(my $OUT,">/tmp/c_netinfo_tmp");
print "SOSA OUT\n";
print "SOSA NAS_VIP=$NAS_VIP\n";
print $OUT "$hostname&$serial_number&$Helios_Join&$Helios_Join_sn&$NAS_VIP&$FW_VER&$Status&$FCWWN[0]&$FCWWN[1]&$model_name&&&";#Minging.Tsai. 2013/7/2, 2013/8/13
print "$hostname&$serial_number&$Helios_Join&$Helios_Join_sn&$NAS_VIP&$FW_VER&$Status&$FCWWN[0]&$FCWWN[1]&$model_name&&&\n";#Minging.Tsai. 2013/7/2, 2013/8/13
for($i=0; $i < $ETH_PORT_NUM; $i++) {
	print $OUT "$inf[$i]&$ip[$i]&$netmask[$i]&$gw[$i]&&";
}
print $OUT "\n";
close($OUT);

system("mv /tmp/c_netinfo_tmp /tmp/c_netinfo_multi");

close LOCKFILE;
exit 0;

#Minging.Tsai. 2013/10/15.	Encrypt the serial number make it not look like a MAC addr.
sub MAC_encrypt
{
	my ($sn) = @_;
	my $extend_key = "GloryGloryManUnited";
	my $res = "";
	$key_offset = 0;
	$i = 6;
	while($key_offset == 0) {#Get a nonzero value as offset.
		$key_offset = substr($sn, $i, 1);#Get the char as key offset.
		$key_offset = ord($key_offset);
		$i = $i + 1 >= 12 ? 0 : $i + 1;
	}
	$extend_key = substr($extend_key, hex(substr($sn, 11, 1)), 4);
	my $extend_sn = $sn.$extend_key;#Extend the sn to 16 chars.
		print "extend_sn=$extend_sn\n";
	for($i = 0; $i < 16; $i++) {
		$char = substr($extend_sn, $i, 1);
		$ord_char = ord($char);
		$ord_char = ($ord_char + $key_offset) % 36;#offset to 0~z
		if($ord_char <= 15) {#0~f
			$hex = sprintf("%x",$ord_char);
		} else {#g~z
			$a = ($ord_char - 16) + 103;
			$hex = chr($a);
		}
		$res .= $hex;
	}
	return $res;
}

