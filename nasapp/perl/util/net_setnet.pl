#!/usr/bin/perl
#Minging.Tsai. 2013/7/2.
#Set parameters into config files, and restart the network.
#Modify from "/usr/sbin/setnet" in 6700.
#Add setResolv
#Initiated by fagent+

require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/setnet_lib.pl";
my $LOG = 0;

$argc = @ARGV;
if ( $argc != 1 ) {
	print "$argc != 1, then exit\n";
	exit(0);
}
if( -f "/tmp/setnet" ) {
	print "if( -f /tmp/setnet ) exit\n";
	exit(0);
}

open( OUT,">/tmp/setnet" );
print OUT "$source\n";
close(OUT);

#Minging.Tsai. 2014.5.28. Check the difference between source and last source.
#Perfrom set_netconf if the source strings are different.
my $last_source = `cat /tmp/setnet_info`;
chomp($last_source);
my $source = $ARGV[0];

if ($LOG){
	print "source=$source\n";
}
#SOSA andy
open( OUT,">/tmp/setnet2" );
print OUT "$source\n";
close(OUT);

#Minging.Tsai.
#Disable the bond1 whenever we change the network setting.
my $ret = 0;
system("ifconfig bond1 down");
if($source ne $last_source) {
	#Set the config if needed.
	$ret = set_netconf($source);
}

exit 1 if($ret == 1);

naslog($NET_EVENT, $LOG_INFORMATION, "100", "Change netowrk setting and restart network.");
system("$NETWORK_SCRIPT restart >/dev/null 2>/dev/null");

sleep 1;

unlink("/tmp/setnet");
system("ifconfig bond1 up");

system("/etc/init.d/keepalived restart");
system("/nasapp/perl/util/lvsng_chktimestamp.pl &");#Check timstamp.

#Minging.Tsai. 2014/7/14. Force update node info after set network.
system("/nasapp/perl/util/net_util_getnet.pl");

