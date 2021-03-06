#!/usr/bin/perl
#Minging.Tsai. 2014.5.28. Add a function to handle the /etc/config/eth* modification independently.
#The input is the same as the original net_setnet which comes from fagent.
#The output is the indicator of bondo changing prework.

require "/nasapp/perl/lib/fs_lib.pl";
sub set_netconf{
	my($source) = @_;
	print "source=$source\n";
	system("echo \"$source\" >/tmp/setnet_lib_info");
	my @netinfo;
	my @inf = ();
	my @ip = ();
	my @nm = ();
	my @gw = ();
	my @SOSAinf = ();
        my @SOSAip = ();
        my @SOSAnm = ();
        my @SOSAgw = ();
	
	#Minging.Tsai. 2014/5/17. Add the handler for IP changing while NASGW still mount on AClass.
	my $bond0_prework = 0;#Minging.Tsai. 2014/5/17. Indicate if the pre-work of changing bond0 IP is done.
	my $mount_info = `cat /nasdata/config/etc/helios.conf`;
	$bond0_prework = 2 if($mount_info eq "");#No need to do the pre-work as well as remount if there is no mount point info.

	#SOSA andy
	print "set_netconf\n";
	#if( $source =~ /(\S+),,(\S+),,(\S+),,(\S+),,(\S+),,(\S+),,/ || $source =~ /(\S+)&&(\S+)&&(\S+)&&(\S+)&&(\S+)&&(\S+)&&/) {
	#SOSA andy two ports
	if( $source =~ /(\S+),,(\S+),,/ || $source =~ /(\S+)&&(\S+)&&/) {
		$netinfo[0] = $1;	$netinfo[1] = $2;
		
		#SOSA andy set up network interface
		my $config_interface="/etc/network/interfaces";
		my $tmp_config_interface="/tmp/interfaces";
                open(OUT,">$tmp_config_interface");
		if( $netinfo[0] =~ /(\S+),(\S+),(\S+),(\S+)/) {
                                print "netinfo[0]=$netinfo[0]\n";
                                $SOSAinf[0] = $1;
                                $SOSAip[0] = $2;
                                $SOSAnm[0] = $3;
                                $SOSAgw[0] = $4;
                               }

                if( $netinfo[1] =~ /(\S+),(\S+),(\S+),(\S+)/) {
                                print "netinfo[1]=$netinfo[1]\n";
                                $SOSAinf[1] = $1;
                                $SOSAip[1] = $2;
                                $SOSAnm[1] = $3;
                                $SOSAgw[1] = $4;
                               }
		print OUT "auto lo $SOSAinf[0] $SOSAinf[1]\n";
                print OUT "iface lo inet loopback\n";
		print OUT "iface $SOSAinf[0] inet static\n";
                print OUT "     address $SOSAip[0]\n";
                print OUT "     netmask $SOSAnm[0]\n";

                print OUT "iface $SOSAinf[1] inet static\n";
                print OUT "	address $SOSAip[1]\n";
		print OUT "	netmask $SOSAnm[1]\n";
		
		close(OUT);

		#Start to parse netinfo if really got them.
		for($i=0; $i<=$#netinfo; $i++) {
			my $config_file_ori="/etc/config/eth".$i;
			my $config_file="/tmp/eth".$i;
			my $bond_group = -1;#Default value, not 0, not 1.
#if( $netinfo[$i] =~ /(\S+),(\S+),(\S+),(\S+),(\S+),(\S+),(\S+),(\S+),(\S+),(\S+),(\S+),(\S+),(\S+),(\S+)/ ) {
			if( $netinfo[$i] =~ /(\S+),(\S+),(\S+),(\S+)/) {
				#print "netinfo[$i]=$netinfo[$i]\n";
				$inf[$i] = $1;
				$ip[$i] = $2;
				$nm[$i] = $3;
				$gw[$i] = $4;
				
				if($ip[$i] !~ /\d+\.\d+\.\d+\.\d+/ || $nm[$i] !~ /\d+\.\d+\.\d+\.\d+/ || $gw[$i] !~ /\d+\.\d+\.\d+\.\d+/) {
					return 1;
				}
				open( OUT,">$config_file" );
				#print OUT "IPV6=NO\n";
				if($inf[$i] =~ /^bond/) {
					#print OUT "BOND=YES\n";
					$bond_group = substr($inf[$i], 4, 1);#Get the bond group number
					#print OUT "BOND_GROUP=$bond_group\n";
					$mode = substr($inf[$i], 6, 1);
					#print OUT "MODE=$mode\n";
				} else {
					#print OUT "BOND=NO\n";
					#print OUT "BOND_GROUP=0\n";
					#print OUT "MODE=x\n";
				}
				#print OUT "PROTO=ip\n";
				#print OUT "IP=$ip[$i]\n";
				#print OUT "NETMASK=$nm[$i]\n";
				#print OUT "GATEWAY=$gw[$i]\n";
				#print OUT "MTU=1500\n";
				#if($i == 4 || $i ==5) {
				#	print OUT "SPEED=10000\n";
				#} else {
				#	print OUT "SPEED=1000\n";
				#}
				close(OUT);
			}#End of if( $netinfo[$i] =~ /(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)&(\S+)/ )
			if($bond0_prework == 0) { 
				$cont_diff = `diff $config_file $config_file_ori`;
				chomp($cont_diff);
				if($cont_diff =~ /IP\=/ && $bond_group == 0) {#bond0 IP has changed.
					print "Perform the bond0 IP changing pre-work.\n";
					$bond0_prework = 1; #enable the bond0 prework flag. Do before_ChangeHeliosIP later.
					before_ChangeHeliosIP("");#Use the current joined A-Class IP.
				}
			}
			system("mv $config_file $config_file_ori");
			system("mv $tmp_config_interface $config_interface");
		}#for($i=0; $i<=$#netinfo; $i++) {
	}#if( $source =~ /(\S+)&&(\S+)&&(\S+)&&(\S+)&&(\S+)&&(\S+)&&/ )
	print "end setnet_lib.pl\n";
	return 0;
}


return 1;
