#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: sys_lib.pl
#  Author: Kylin Shih
#  Date: 2012/11/27
#  Description:
#    Sub-routines for system.
#########################################################################

require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/pro_lib.pl";
require "/nasapp/perl/lib/sys_lib.pl";
require "/nasapp/perl/lib/log_db_lib.pl";

#########################################################
#  Set hostname
#  Input: hostname(string)
#  Output:  0=OK, 1=FAIL
#  Example: sethostname("DualNasName");
#########################################################
sub sethostname
{
	my($newHostname) = @_;

	# $newHostname =~ s/\-/\_/g; # replace "-" with "_" for bonjour compatibility, for now it should not need to use
	# print "$newHostname\n";
	$oldHostname = `$UNAME_CMD -n`;
	chomp $oldHostname;
	# print "$oldHostname\n";

	# hostname do not need to change
	if ($newHostname eq $oldHostname) {
		return 0;
	}

	# Set new hostname for SAMBA
	$smbin = gen_random_filename($SMB_CONF);
	$smbout = gen_random_filename($SMB_CONF);
	system("$CP_CMD -f \"$SMB_CONF\" \"$smbin\"");
	open(my $OUT, ">$smbout");
	open(my $IN, $smbin);
	while(<$IN>) {
		if (/server\s+string\s+\=\s+.*/) {
			print $OUT "	server string = \U$newHostname\n";
		}
		else {
			$line = $_;
			print $OUT "$line";
			if( $line =~ /workgroup\s+\=\s+(\S*)/ ){
				my $domain = "\L$1";
				chomp $domain;
			}
		}
	}
	close($IN);
	close($OUT);

	copy_file_to_realpath($smbout,$SMB_CONF);
	unlink($smbin);
	unlink($smbout);
	#print "Samba config complete\n";
	
	# @todo
	# Set new hostname for AFP
	#$afptmp = $TMP_PATH.rand;
	#open(OUT,">$afptmp");
	#open(IN, $USR_LOCAL_NETATALK_NETATALK_CONF);
	#while (<IN>){
	#  if ( /^\s*ATALK_NAME=([\S\s]+)/ ) {
	#	     print OUT "ATALK_NAME=\U$newHostname\n";
	#  }
	#  else {
	#	     print OUT "$_";
	#  }
	#}
	#close (IN);
	#close (OUT);
	#system ("$CP_CMD -f $afptmp $USR_LOCAL_NETATALK_NETATALK_CONF");
	#system ("$CP_CMD -f $afptmp $DATA_USR_NETATALK_NETATALK_CONF");
	#unlink($afptmp);

	# @todo
	# Set new hostname for FTP
	#$ftptmp = $TMP_PATH.rand;
	#open(OUT, ">$ftptmp");
	#open(IN, $USR_LOCAL_ETC_PROFTPD_CONF);
	#while (<IN>) {
	#      if (/^\s*ServerName\s+\"[\S\s]+\"/) {
	#            print OUT "ServerName		\"\U$newHostname FTP Server\"\n";
	#      }
	#	  else {
	#            print OUT "$_";
	#      }
	#}
	#close(IN);
	#close(OUT);
	#system("$CP_CMD -f $ftptmp $USR_LOCAL_ETC_PROFTPD_CONF");
	#system("$CP_CMD -f $ftptmp $DATA_USR_ETC_PROFTPD_CONF");
	#unlink($ftptmp);

	# Set new hostname to system and config
	system("$ECHO_CMD \"$newHostname\" >$CONF_HOSTNAME");

	# Use command to change system hostname(not permanent)
	system("$HOSTNAME_CMD $newHostname");
	# print "hostname command complete\n";

	#system("/promise/util/setISCSInodename.pl"); # @todo

	# Update /etc/hosts
	set_conf_hosts($newHostname, $domain);
	# print "/etc/hosts complete\n";

	# mark reload protocol flag
	mark_reload_protocol("ALL");
	return 0;
}
#########################################################
#  Set hostname
#  Input: hostname(string)
#  Output:  0=OK, 1=FAIL
#  Example: sethostname("DualNasName");
#########################################################
#Minging.Tsai. 2013/8/19.
sub setreboot
{
	my($option) = @_;
	if($option == 0) {
		#Shutdown
		system("init 0");
	} elsif($option == 1) {
		#Reboot
		system("init 6");
	} else {
		exit 1;
	}	
}

########################################################################
#  input: -
#  output: a hash contains information with keys {type, location, measure}
#  desc: get enclosure information by ipmitool
#  author: Paul.Chang
#  date: 2013/09/27
########################################################################
sub get_enclosure_info {
	my @result = ();
	
	open (my $IN, "$IPMITOOL_CMD sdr list full |");
	while(<$IN>) {
		my $info = $_;
		chomp $info;
		my @tmpStr = split(/\|/, $info);
		my $location = $tmpStr[0];
		my $measure = $tmpStr[1];
		$location =~ s/^\s+|\s+$//g;
		$measure =~ s/^\s+|\s+$//g;
		if ($measure =~ /^(\S+)\s+(.+)/) {
			my $type = "";
			$measure = "$1";
			if ($2 eq "degrees C") {
				$type = "temperature";
			}
			elsif ($2 eq "Volts") {
				$type = "voltage";
			}
			elsif ($2 eq "RPM") {
				$type = "fan_speed";
			}
			#Get the status
			print "$location $type $measure\n";
			my $status = 0;
			if ($type eq "temperature") {
				if ($location eq "CPU1 Temperature") {
					if (90 < $measure) {
						$status = 2;
						send_warning($location,"$location $measure is above the critical threshold! Shutdown the NAS Gateway node",$LOG_ERROR);
						system("init 0");
					}elsif(60 < $measure || 1 > $measure) {
						$status = 1;
						send_warning($location,"$location $measure is above or below the warning threshold!",$LOG_WARNING);
					}else{
						delete_warning_file($location);
					}
				}
				elsif ($location eq "MB1 Temperature") {
					if (90 < $measure) {
						$status = 2;
						send_warning($location,"$location $measure is above the critical threshold! Shutdown the NAS Gateway node",$LOG_ERROR);
						system("init 0");
					}elsif(60 < $measure || 1 > $measure) {
						$status = 1;
						send_warning($location,"$location $measure is above the warning threshold!",$LOG_WARNING);
					}else{
						delete_warning_file($location);
					}
				}
			}
			elsif ($type eq "voltage") {
				if ($location eq "+12V") {
					if (12*0.90 > $measure || 12*1.10 < $measure) {
						$status = 1;
						send_warning($location,"Voltage of power supply unit is unusual!",$LOG_WARNING);
					}else{
						delete_warning_file($location);
					}
				}
				elsif ($location eq "+5V") {
					if (5*0.95 > $measure || 5*1.05 < $measure) {
						$status = 1;
						send_warning($location,"Voltage of power supply unit is unusual!",$LOG_WARNING);
					}else{
						delete_warning_file($location);
					}

				}
				elsif ($location eq "+3.3V") {
					if (3.3*0.90 > $measure || 3.830 < $measure) {
						$status = 1;
						send_warning($location,"voltage3","Voltage of power supply unit is unusual!",$LOG_WARNING);
					}else{
						delete_warning_file($location);
					}

				}
			}
			elsif ($type eq "fan_speed") {
				if ($location eq "CPU_FAN1" || $location eq "FRNT_FAN2" || $location eq "FRNT_FAN3" || $location eq "FRNT_FAN1" || $location eq "REAR_FAN1" ) {
					if ($measure < 1000) {
                        $status = 1;
						send_warning($location,"$location speed $measure is below the warning threshold!",$LOG_ERROR);
					}
					elsif ($measure > 20000) {
                        $status = 1;
						send_warning($location,"$location speed $measure is above the warning threshold!",$LOG_WARNING);
					}else{
						delete_warning_file($location);
					}
				}
			}

			if ($type ne "") {
				push @result, {"type" => "$type", "location" => "$location", "measure" => "$measure", "status" => "$status"};
			}
		}
		if($location =~/PMBPower/){
			if($measure eq "no"){
				$measure = 0;
			}
			$status = $measure == 0 ? 1 : 0;
			print "location=$location, measure=$measure, status=$status\n";
			if($status eq 1){
				send_warning($location,"$location power is not working",$LOG_WARNING);
			}else{
				delete_warning_file($location);
			}
			push @result, {"type" => "power","location"=>"$location","measure" => $measure, "status" => $status};
		}
	}
	close($IN);
	
	#Minging.Tsai. 2014/9/4. Add FC WWN info and linkup status into enclosure report.
	#Get FC WWN and linkup status
	my @fc_info = get_fc_status();
	my @fc_wwn = ();
	$fc_wwn[0] = $fc_info[0]{"WWPN"};
	$fc_wwn[1] = $fc_info[1]{"WWPN"};
	$fc_wwn[0] = "FCWWN0" if($fc_wwn[0] eq "");
	$fc_wwn[1] = "FCWWN1" if($fc_wwn[1] eq "");

	my @fc_linkup = ();
	$fc_linkup[0] .= $fc_info[0]{"LINK"} eq Online ? 1 : 0;#Convert Online/Linkdown to 0/1
	$fc_linkup[1] .= $fc_info[1]{"LINK"} eq Online ? 1 : 0;#Convert Online/Linkdown to 0/1

	for($i=0;$i<2;$i++){
		my $location = "fc_$i";
		print "location=$location\n";
		if($fc_linkup[$i]){
				send_warning($location,"$location is not connected",$LOG_WARNING);
		}else{
				delete_warning_file($location);
		}
	}

	push @result, {"type" => "fc","location"=>"fc_0","measure" => $fc_wwn[0], "status" => $fc_linkup[0]};
	push @result, {"type" => "fc","location"=>"fc_1","measure" => $fc_wwn[1], "status" => $fc_linkup[1]};


	return @result;
}


########################################################################
#  input: -
#  output: raid information
#  desc: get raid information of NAS gateway
#  author: Paul.Chang
#  date: 2013/10/02
########################################################################
sub get_raid_info {
	my @result = ();
	my $DaId = "";
	my $OperationalStatus = "";
	my $Alias = "";
	my $PhysicalCapacity = "";
	my $ConfigurableCapacity = "";
	my $FreeCapacity = "";
	my $MaxContiguousCapacity = "";
	my $AvailableRAIDLevels = "";
	my $PDM = "";
	my $MediaPatrol = "";
	my $NumberOfPhysicalDrives = "";
	my $NumberOfLogicalDrives = "";
	my $NumberOfDedicatedSpares = "";
	my $PowerManagement = "";
	my $separator = 0;
	my $PDStatusStr = "";
	my $LDStatusStr = "";
	my $ASStatusStr = "";
	
	open (my $IN, "$I2ARYTOOL_GET_CMD array -v |");
	while(<$IN>) {
		if (/DaId:\s+(\d+)/) {
			$DaId = $1;
		}
		elsif (/OperationalStatus:\s+(.+)/) {
			$OperationalStatus = trim($1);
		}
		elsif (/Alias:\s+(\S+)/) {
			$Alias = $1;
		}
		elsif (/PhysicalCapacity:\s+(.+)ConfigurableCapacity:\s+(.+)/) {
			$PhysicalCapacity = trim($1);
			$ConfigurableCapacity = trim($2);
		}
		elsif (/FreeCapacity:\s+(.+)MaxContiguousCapacity:\s+(.+)/) {
			$FreeCapacity = trim($1);
			$MaxContiguousCapacity = trim($2);
		}
		elsif (/AvailableRAIDLevels:\s+(.+)/) {
			$AvailableRAIDLevels = trim($1);
		}
		elsif (/PDM:\s+(.+)MediaPatrol:\s+(.+)/) {
			$PDM = trim($1);
			$MediaPatrol = trim($2);
		}
		elsif (/NumberOfPhysicalDrives:\s+(\d+)\s+NumberOfLogicalDrives:\s+(\d+)\s+/) {
			$NumberOfPhysicalDrives = $1;
			$NumberOfLogicalDrives = $2;
		}
		elsif (/NumberOfDedicatedSpares:\s+(\d+)/) {
			$NumberOfDedicatedSpares = $1;
		}
		elsif (/PowerMgmt:\s+(\S+)/) {
			$PowerManagement = $1;
		}
		elsif (/=+/) {
			$separator += 1;
		}
		if ($separator == 2 && /^(\S+)\s+(\S+)\s+(\S+(Byte|Bytes|KB|GB|TB|PB))\s+(\S+(Byte|Bytes|KB|GB|TB|PB))\s+(\S+)/) {
			if ($PDStatusStr ne "") {
				$PDStatusStr .= ",";
			}
			$PDStatusStr .= "($1,$2,$3,$5,$7)";
		}
		if ($separator == 4 && /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+(Byte|Bytes|KB|GB|TB|PB))\s+(\S+)/) {
			if ($LDStatusStr ne "") {
				$LDStatusStr .= ",";
			}
			$LDStatusStr .= "($1,$2,$3,$4,$6)";
		}
		if ($separator == 6 && /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+(Byte|Bytes|KB|GB|TB|PB))\s+(\S+)\s+(\S+)\s+(\S+)/) {
			if ($ASStatusStr ne "") {
				$ASStatusStr .= ",";
			}
			$ASStatusStr .= "($1,$2,$3,$4,$6,$7,$8)";
		}
		
		if (/-+/ && $DaId ne "") {
			push @result, {"DaId" => "$DaId",
			               "OperationalStatus" => "$OperationalStatus",
						   "Alias" => "$Alias",
						   "PhysicalCapacity" => "$PhysicalCapacity",
						   "ConfigurableCapacity" => "$ConfigurableCapacity",
						   "FreeCapacity" => "$FreeCapacity",
						   "MaxContiguousCapacity" => "$MaxContiguousCapacity",
						   "AvailableRAIDLevels" => "$AvailableRAIDLevels",
						   "PDM" => "$PDM",
						   "MediaPatrol" => "$MediaPatrol",
						   "NumberOfPhysicalDrives" => "$NumberOfPhysicalDrives",
						   "NumberOfLogicalDrives" => "$NumberOfLogicalDrives",
						   "NumberOfDedicatedSpares" => "$NumberOfDedicatedSpares",
						   "PowerManagement" => "$PowerManagement",
						   "PhysicalDrivesStatus" => "$PDStatusStr",
						   "LogicalDrivesStatus" => "$LDStatusStr",
						   "AvailableSparesStatus" => "$ASStatusStr"};
			$DaId = "";
			$OperationalStatus = "";
			$Alias = "";
			$PhysicalCapacity = "";
			$ConfigurableCapacity = "";
			$FreeCapacity = "";
			$MaxContiguousCapacity = "";
			$AvailableRAIDLevels = "";
			$PDM = "";
			$MediaPatrol = "";
			$NumberOfPhysicalDrives = "";
			$NumberOfLogicalDrives = "";
			$NumberOfDedicatedSpares = "";
			$PowerManagement = "";
			$separator = 0;
			$PDStatusStr = "";
			$LDStatusStr = "";
			$ASStatusStr = "";
		}
	}
	close($IN);
	if ($DaId ne "") {
		push @result, {"DaId" => "$DaId",
		               "OperationalStatus" => "$OperationalStatus",
					   "Alias" => "$Alias",
					   "PhysicalCapacity" => "$PhysicalCapacity",
					   "ConfigurableCapacity" => "$ConfigurableCapacity",
					   "FreeCapacity" => "$FreeCapacity",
					   "MaxContiguousCapacity" => "$MaxContiguousCapacity",
					   "AvailableRAIDLevels" => "$AvailableRAIDLevels",
					   "PDM" => "$PDM",
					   "MediaPatrol" => "$MediaPatrol",
					   "NumberOfPhysicalDrives" => "$NumberOfPhysicalDrives",
					   "NumberOfLogicalDrives" => "$NumberOfLogicalDrives",
					   "NumberOfDedicatedSpares" => "$NumberOfDedicatedSpares",
					   "PowerManagement" => "$PowerManagement",
					   "PhysicalDrivesStatus" => "$PDStatusStr",
					   "LogicalDrivesStatus" => "$LDStatusStr",
					   "AvailableSparesStatus" => "$ASStatusStr"};
	}
	
	return @result;
}

########################################################################
#  input: -
#  output: raid information
#  desc: get raid information of NAS gateway
#  author: Paul.Chang
#  date: 2013/10/02
########################################################################
sub get_bga_status {
	my @result = ();
	my $type = "";
	my $status = "";
	my $progress = 0;
	
	open (my $IN, "$I2ARYTOOL_GET_CMD bga -v |");
	while(<$IN>) {
		if (/Rebuild Progress:/) {
			$type = "Rebuild";
		}
		elsif (/PDM Progress:/) {
			$type = "PDM";
		}
		elsif (/Transition Progress:/) {
			$type = "Transition";
		}
		elsif (/Synchronization Progress:/) {
			$type = "Synchronization";
		}
		elsif (/Initialization Progress:/) {
			$type = "Initialization";
		}
		elsif (/Redundancy Check Progress:/) {
			$type = "Redundancy Check";
		}
		elsif (/Media Patrol Progress:/) {
			$type = "Media Patrol";
		}
		elsif (/Spare Check Progress:/) {
			$type = "Spare Check";
		}
		elsif (/Migration Progress:/) {
			$type = "Migration Progress";
		}
		elsif (/^(\d+)\s+(\S+)\s+(\d+)/) {  #Synchronization, Initialization, Redundancy Check
			$status = $2;
			$progress = $3;
			push @result, {"type" => "$type", "status" => "$status", "progress" => "$progress"};
		}
		elsif (/^(\d+)\s+(\d+)\s+(\S+)/) {  #Spare Check
			$status = $3;
			$progress = "";
			push @result, {"type" => "$type", "status" => "$status", "progress" => "$progress"};
		}
		elsif (/^(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {  #Rebuild, PDM, Transition
			$status = $3;
			$progress = $8;
			push @result, {"type" => "$type", "status" => "$status", "progress" => "$progress"};
		}
		# parse Media Patrol Progress
		elsif (/State:\s+(\S+)\s+OverallPercentage:\s+(\d+)/) {
			$status = $1;
			$progress = $2;
			push @result, {"type" => "$type", "status" => "$status", "progress" => "$progress"};
		}
		# parse Migration Progress
		elsif (/State:\s+(\S+)\s+CompletionPercentage:\s+(\d+)/) {
			$status = $1;
			$progress = $2;
			push @result, {"type" => "$type", "status" => "$status", "progress" => "$progress"};
		}
	}
	close($IN);
	return @result;
}

sub get_fc_status
{
	my @FCdev = ();
	my @fc_host = ();
	my $count = 0;
	open(my $HOST_IN, "ls /sys/class/fc_host/ | grep host |");
	while(<$HOST_IN>) {
		if(/(host\d+)/) {
			$fc_host[$count] = $1;
			$count++;
		}
	}
	close($HOST_IN);
	foreach my $host (@fc_host) {
		$port_file = "/sys/class/fc_host/$host/port_name";
		$link_file = "/sys/class/fc_host/$host/port_state";
		$speed_file = "/sys/class/fc_host/$host/speed";
		my $port_name=`cat $port_file`;
		my $port_status = `cat $link_file`;
		my $port_speed = `cat $speed_file`;
		chomp $port_name;
		chomp $port_status;
		chomp $port_speed;
		push @FCdev, {"WWPN" => "$port_name","LINK" => "$port_status","SPEED" => "$port_speed","HOST"=>"$host"};
	}
	return @FCdev;
}
sub get_eth_status
{
	my @ethdev = ();
	my @eth_host = ();
	my $count = 0;
	open(my $HOST_IN, "ls /sys/class/net/ | grep eth |");
	while(<$HOST_IN>) {
		if(/(eth\d)/) {
			$eth_host[$count] = $1;
			$count++;
		}
	}
	close($HOST_IN);
	foreach my $host (@eth_host) {
		$port_file = "/sys/class/net/$host/address";
		$link_file = "/sys/class/net/$host/carrier";
		$speed_file = "/sys/class/net/$host/speed";
		my $port_name=`cat $port_file`;
		my $port_status = `cat $link_file`;
		my $port_speed = `cat $speed_file`;
		chomp $port_name;
		chomp $port_status;
		chomp $port_speed;
		push @ethdev, {"interface" => "$host","MAC_addr" => "$port_name","LINK" => "$port_status","SPEED" => "$port_speed"};
	}
	if($count <= 4) {#Don't have 10G
		push @ethdev, {"interface" => "eth4","MAC_addr" => "XXXXXXXXXXXX","LINK" => "0","SPEED" => "-1"};
		push @ethdev, {"interface" => "eth5","MAC_addr" => "XXXXXXXXXXXX","LINK" => "0","SPEED" => "-1"};
	}

	for($i = 0; $i < 2; $i++) {
		$port_file = "/sys/class/net/bond$i/address";
		$link_file = "/sys/class/net/bond$i/carrier";
#Cannot get speed from bond
#		$speed_file = "/sys/class/net/bond$i/speed";
		my $port_name = -e $port_file ? `cat $port_file` : "XXXXXXXXXXXX";
		my $port_status = -e $link_file ? `cat $link_file` : "0";
#		my $port_speed = `cat $speed_file`;
		chomp $port_name;
		chomp $port_status;
#		chomp $port_speed;
		push @ethdev, {"interface" => "bond$i", "MAC_addr" => "$port_name","LINK" => "$port_status","SPEED" => "0"};
	}
	return @ethdev;
}
return 1;  # this is required.
sub delete_warning_file {
    my ($location)=@_;
	system("rm -f \"/tmp/" . $location ."_\"*");
}
sub send_warning {
    my ($location,$message,$level) = @_;

    # send mail
    # turn on buzzer
    system("$BEEP_CMD -l 8000 &");

    # write log
    #naslog($LOG_MISC_NASEVENT, $LOG_WARNING, "12", "[Enclosure_Alert]: $message");
    if(! -f "/tmp/" . $location . "_" .$level){
        sendmail($message);
        naslog($LOG_MISC_NASEVENT, $level, "12", "[Enclosure_Alert]: $message");
        delete_warning_file($location);
        system("touch \"/tmp/" . $location . "_" . $level . "\"" );
    }
    return 0;
}
sub write_status_detail
{
	#type: protocol, enclosure, mount, FW upgrade, raid, config syncing.
	my ($type , $status) = @_;
	if(! -e "/tmp/sys_status_detail") { #Generate the origin file if the file doesn't exist.
		system("echo \"Protocol=0\" >>/tmp/sys_status_detail");
		system("echo \"Enclosure=0\" >>/tmp/sys_status_detail");
		system("echo \"Mount=0\" >>/tmp/sys_status_detail");
		system("echo \"Upgrade=0\" >>/tmp/sys_status_detail");
		system("echo \"Raid=0\" >>/tmp/sys_status_detail");
		system("echo \"Syncing=0\" >>/tmp/sys_status_detail");
		system("echo \"Eth_bond0=0\" >>/tmp/sys_status_detail");
		system("echo \"Eth_bond1=0\" >>/tmp/sys_status_detail");
		system("echo \"Fiber=0\" >>/tmp/sys_status_detail");
		system("echo \"Domain=0\" >>/tmp/sys_status_detail");
		system("echo \"Cluster=0\" >>/tmp/sys_status_detail");
	}
	my @cont = ();
	open(my $IN, "/tmp/sys_status_detail");
	@cont = <$IN>;
	close($IN);

	my $out = "";
	my $sum_status = 0;
	my $match = 0;
	foreach $line (@cont) {
		if($line =~ /(\S+)\=(\S+)/) {
			#0:OK, 
			#1,3,5,7,9:wanring
			#2,4,6,8:critical
			my $current_status = $2;
			if($1 eq $type) {
				$out .= "$1=$status\n";
				$match = 1;
				if($status != 0) {#not OK
					#Collect the status summary.
					$sum_status = 1 if($status % 2 == 1 && $sum_status < 2);
					$sum_status = 2 if($status % 2 == 0);
				}
			} else {
				$out .= "$line";
				if($current_status != 0) {#not OK
					#Collect the status summary.
					$sum_status = 1 if($current_status % 2 == 1 && $sum_status < 2);
					$sum_status = 2 if($current_status % 2 == 0);
				}
			}
		}
	}
	$out .= "$type=$status\n" if($match == 0);
    open(my $OUT, ">/tmp/sys_status_detail");
	print $OUT $out;
    close($OUT);
	system("echo \"$sum_status\" >$CONF_SYS_STATUS");
}
sub sendmail {
    my ($message) = @_;
    my $tempstr, $maillist = "";

    my $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst;
    my $yyear;
    my $ymon;
    my $present_time;

    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    $yyear=$year+1900;
    $ymon=(Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mon];
    $mday=(sprintf "%2d",$mday);
    $hour=(sprintf "%.2d",$hour);
    $min=(sprintf "%.2d",$min);
    $sec=(sprintf "%.2d",$sec);
    $present_time="$ymon $mday $yyear $hour:$min:$sec";

    $maillist = getmaillist();

    my $alertmsg = gen_random_filename();
    open( OUT, ">$alertmsg" );
    print OUT "Notification from NAS Gateway!\n\n";
    print OUT "Message: $message\n\n";
    print OUT "Date: $present_time\n\n";
    close(OUT);

    if ($maillist ne "") {
        system("$MAIL_CMD -s \"Notification from NAS Gateway !\" $maillist < $alertmsg >/dev/null 2>/dev/null &");
    }
    unlink($alertmsg);
    return 0;
}
sub getmaillist {
    my $maillist, $tempstr;

    $maillist = "";
    open(my $IN, "<$CONF_MAIL");
    while(<$IN>) {
        $tempstr = $_;
        chomp($tempstr);
        $maillist = $maillist . $tempstr . " ";
    }
    close($IN);

    return $maillist;
}

sub Checknodestatus{
	my @rip=();
 	my $master_flag = `ifconfig lo:0 | grep 'inet addr:'` eq "" ? 1 : 0;
	open(my $IN,"/nasdata/config/etc/rip.conf");
	while(<$IN>){
	    if(/(\S+),\d+/){
			            push @rip,$1;
						    }
	}
	close($IN);
	my @dip=();
	open($IN,"ipvsadm -ln | ");
	while(<$IN>){
#  -> 192.168.11.51:0              Local   3      0          0
      if(/->\s+(\S+):0\s+(\S+)/){
          push @dip,{"ip"=>$1,"locate"=>$2};
      }
    }
    close(IN);
    my $rcount = @rip;
    my $dcount = @dip;
    if($rcount == $dcount){
		  unlink("/tmp/localfail");
          return 0;
    }elsif($dcount==0){
        if($master_flag ==0){
            return 2;
        }
		return 3;
	}else{
        foreach $ip(@dip){
           if($ip->{"locate"} eq "Local"){
				if($master_flag ==0){
					return 0;
				}else{
					return 1;
				}
           }
	    }
    }
    if(! -f "/tmp/localfail"){
		system("touch /tmp/localfail");
		system("echo 3 > /proc/sys/vm/drop_caches");
	} 
	return 2;
}


