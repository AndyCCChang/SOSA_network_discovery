#!/usr/bin/perl
#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: pro_lib.pl
#  Author: Paul Chang
#  Modify: Minging.Tsai. 2013/8/16. Modify import_protocol_settings for NAS gateway.
#  Date: 2012/11/21
#  Description:
#    Tools used in protocol.
#########################################################################

require "/nasapp/perl/lib/pro_smb_lib.pl";
require "/nasapp/perl/lib/pro_afp_lib.pl";
require "/nasapp/perl/lib/pro_ftp_lib.pl";
require "/nasapp/perl/lib/pro_webdav_lib.pl";
require "/nasapp/perl/lib/fs_lib.pl";
require "/nasapp/perl/lib/perm_lib.pl";
require "/nasapp/perl/lib/bk_ssh_lib.pl";

#########################################################
#  Start inout protocol
#  Input:   protocol name(ALL, RESTART, SMB, NFS, AFP, FTP, WEBDAV)
#           ALL means all protocols, RESTART means reload and restart all protocols
#  Output:  0=OK, 1=no such protocol
#  Example: mark_reload_protocol(ALL);
#########################################################
sub mark_reload_protocol {
	my($protocol) = @_;
	my $isMaster = `$GETHISCTLRINFO_CMD -m`; chomp($isMaster);
	
	if ($isMaster == 1) {
		if ($protocol eq "ALL") {
			system("$ECHO_CMD \"1\" > $PRO_RELOAD_ALL");
		}
		elsif ($protocol eq "RESTART") {
			system("$ECHO_CMD \"1\" > $PRO_RELOAD_RESTART");
		}
		elsif ($protocol eq "SMB") {
			system("$ECHO_CMD \"1\" > $PRO_RELOAD_SMB");
		}
		elsif ($protocol eq "NFS") {
			system("$ECHO_CMD \"1\" > $PRO_RELOAD_NFS");
		}
		elsif ($protocol eq "AFP") {
			system("$ECHO_CMD \"1\" > $PRO_RELOAD_AFP");
		}
		elsif ($protocol eq "FTP") {
			system("$ECHO_CMD \"1\" > $PRO_RELOAD_FTP");
		}
		elsif ($protocol eq "WEBDAV") {
			system("$ECHO_CMD \"1\" > $PRO_RELOAD_WEBDAV");
		}
		else {
			return 1;
		}
	}
	else {
		if ($protocol eq "ALL") {
			SSHSystem("$ECHO_CMD \"1\" > $PRO_RELOAD_ALL");
		}
		elsif ($protocol eq "RESTART") {
			SSHSystem("$ECHO_CMD \"1\" > $PRO_RELOAD_RESTART");
		}
		elsif ($protocol eq "SMB") {
			SSHSystem("$ECHO_CMD \"1\" > $PRO_RELOAD_SMB");
		}
		elsif ($protocol eq "NFS") {
			SSHSystem("$ECHO_CMD \"1\" > $PRO_RELOAD_NFS");
		}
		elsif ($protocol eq "AFP") {
			SSHSystem("$ECHO_CMD \"1\" > $PRO_RELOAD_AFP");
		}
		elsif ($protocol eq "FTP") {
			SSHSystem("$ECHO_CMD \"1\" > $PRO_RELOAD_FTP");
		}
		elsif ($protocol eq "WEBDAV") {
			SSHSystem("$ECHO_CMD \"1\" > $PRO_RELOAD_WEBDAV");
		}
		else {
			return 1;
		}
	}
	return 0;
}

#########################################################
#  Start inout protocol
#  Input:   protocol name(SMB, NFS, AFP, FTP, WEBDAV)
#  Output:  0=OK, 1=no such protocol
#  Example: startprotocol(SMB);
#########################################################
sub startprotocol {
	my($protocol) = @_;
	my $res = 0;
	
	# start SMB
	if ($protocol eq "SMB") {
		setprotocolenabled(SMB, YES); # must set yes first due to /etc/init.d/smb script
		$res = system("$SERVICE_CMD smb start >/dev/null 2>/dev/null");
	}
	
	#start NFS
	elsif ($protocol eq "NFS") {
		setprotocolenabled(NFS, YES);
		$res = system("$SERVICE_CMD unfsd start >/dev/null 2>/dev/null");
	}

	#start AFP
	elsif ($protocol eq "AFP") {
		setprotocolenabled(AFP, YES);
		$res = system("$SERVICE_CMD netatalk start >/dev/null 2>/dev/null");
	}

	#start FTP
	elsif ($protocol eq "FTP") {
		$res = system("$SERVICE_CMD ftp start >/dev/null 2>/dev/null");
		sleep 1;
		setprotocolenabled(FTP, YES);
	}

	#start WEBDAV
	elsif ($protocol eq "WEBDAV") {
		my $config = "Include conf/extra/web_dav.conf\n";
		my $httptmp = gen_random_filename("$APACHE_CONF");
		system("$CP_CMD -f $APACHE_CONF $httptmp");	
		system("sed -e /web_dav/d $APACHE_CONF > $httptmp");
		open(my $OUT, ">>$httptmp");
		print $OUT "$config";
		close($OUT);
		copy_file_to_realpath($httptmp, $APACHE_CONF);
		unlink($httptmp);	
		setprotocolenabled(WEBDAV, YES);
		# Use apachetcl -k graceful to reload apache config to prevent kill process from UI
		mark_reload_protocol("WEBDAV");
	}
    elsif($protocol eq "keepalived") {	
	    $res = system("$SERVICE_CMD keepalived start >/dev/null 2>/dev/null");	
        sleep 1;
        setprotocolenabled(keepalived, YES);
	}
	#No such protocol
	else {
		return 1;
	}
	
	if ($res != 0) {
		return 2;
	}
	#system("$SERVICE_CMD bonjour start & >/dev/null 2>/dev/null");
	return 0;
}

#########################################################
#  Stop inout protocol
#  Input:   protocol name(SMB, NFS, AFP, FTP, WEBDAV)
#  Output:  0=OK, 1=no such protocol
#  Example: stopprotocol(SMB);
#########################################################
sub stopprotocol {
	my($protocol) = @_;
	my $res = 0;
	
	# stop SMB
	if ($protocol eq "SMB") {
		$res = system("$SERVICE_CMD smb stop >/dev/null 2>/dev/null");
		setprotocolenabled(SMB, NO);
	}

	#stop NFS
	elsif ($protocol eq "NFS") {
		$res = system("$SERVICE_CMD unfsd stop >/dev/null 2>/dev/null");
		setprotocolenabled(NFS, NO);
	}

	#stop AFP
	elsif ($protocol eq "AFP") {
		$res = system("$SERVICE_CMD netatalk stop >/dev/null 2>/dev/null");
		setprotocolenabled(AFP, NO);
	}

	#stop FTP
	elsif ($protocol eq "FTP") {
		$res = system("$SERVICE_CMD ftp stop >/dev/null 2>/dev/null");
		setprotocolenabled(FTP, NO);
	}

	#stop WEBDAV
	elsif ($protocol eq "WEBDAV") {
		$httptmp = gen_random_filename("$APACHE_CONF");
		system("$CP_CMD -f $APACHE_CONF $httptmp");
		system("sed -e /web_dav/d $APACHE_CONF > $httptmp");
		copy_file_to_realpath($httptmp, $APACHE_CONF);
		unlink($httptmp);
		setprotocolenabled(WEBDAV, NO);
		# Use apachetcl -k graceful to reload apache config to prevent kill process from UI
		mark_reload_protocol("WEBDAV");
	}
	elsif($protocol eq "keepalived") {	
	    $res = system("$SERVICE_CMD keepalived stop >/dev/null 2>/dev/null");	
        sleep 1;
        setprotocolenabled(keepalived, NO);
	}

	#No such protocol
	else {
		return 1;
	}

	if ($res != 0) {
		return 2;
	}
	#system("$SERVICE_CMD bonjour start & >/dev/null 2>/dev/null");
	return 0;
}

#########################################################
#  Get input protocol running status
#  Input:   protocol name(SMB, NFS, AFP, FTP, WEBDAV), ALL for all protocol
#  Output:  a hash contains protocol status (ON/OFF) with keys {SMB, NFS, AFP, FTP, WEBDAV}
#  Example: getprotocolstatus(SMB);
#########################################################
sub getprotocolstatus {
	my($protocol) = @_;
	my %Status;
	my %result;
	
	$Status{"smb"} = "OFF";
	$Status{"nfs"} = "OFF";
	$Status{"afp"} = "OFF";
	$Status{"ftp"} = "OFF";
	$Status{"webdav"} = "OFF";
	$Status{"keepalived"} = "OFF";
	# check protocol running status by using ps
	open (my $RUN, "$PS_CMD |");
	while (<$RUN>) {
#		if(/\/usr\/local\/samba\/bin\/smbd/) {
#        if(/smbd /){ #hanly.chen 2013/8/6
#			$Status{"smb"} = "ON";
#		}
#		if(/\/usr\/local\/sbin\/unfsd\s+/) {
#		if(/$NFSD/){ #hanly.chen 2013/8/6
#			$Status{"nfs"} = "ON";
#		}	
		if(/\/usr\/local\/netatalk\/sbin\/atalkd/) {
			$Status{"afp"} = "ON";
		}
		if(/\/usr\/local\/netatalk\/sbin\/afpd/) {
			$Status{"afp"} = "ON";
		}
		if(/proftpd/) {
			$Status{"ftp"} = "ON";
		} 
		if(/\/apache2\/bin\/httpd/) {
			open (my $IN, "<$APACHE_CONF");
			while (<$IN>) {
				if(/conf\/extra\/web_dav.conf/) {
					$Status{"webdav"} = "ON";
				}
			}
			close($IN);		
		}
		if(/\/usr\/sbin\/keepalived/){
			$Status{"keepalived"} = "ON";
		}
	}
	close ($RUN);
	
	#Minging.Tsai. 2014/2/12.
    my $nfs_on = `pidof unfsd | wc -w`;
    chomp($nfs_on);
    print "number of unfsd=$nfs_on\n";	
	open(IN,"/etc/unfsd.conf");
	while(<IN>){
		if(/unfsd_count=(\d+)/){
			$unfsd_count =$1;
		}
	}
	close(IN);	
    $Status{"nfs"} = "ON" if($nfs_on == $unfsd_count);

	my $smb_on = `pidof smbd | wc -w`;
	chomp($smb_on);
	print "number of smbd=$smb_on\n";
	$Status{"smb"} = "ON" if($smb_on != 0);

	if ($protocol eq "SMB" || $protocol eq "ALL") {
		$result{"SMB"} = $Status{"smb"};
	}
	if ($protocol eq "NFS" || $protocol eq "ALL") {
		$result{"NFS"} = $Status{"nfs"};
	}
	if ($protocol eq "AFP" || $protocol eq "ALL") {
		$result{"AFP"} = $Status{"afp"};
	}
	if ($protocol eq "FTP" || $protocol eq "ALL") {
		$result{"FTP"} = $Status{"ftp"};
	}
	if ($protocol eq "WEBDAV" || $protocol eq "ALL") {
		$result{"WEBDAV"} = $Status{"webdav"};
	}
	if ($protocol eq "keepalived" || $protocol eq "ALL") {
		$result{"keepalived"} = $Status{"keepalived"};
	}

	
	return %result;
}

#########################################################
#  Get input protocol is enabled or not
#  Input:   protocol name(SMB, NFS, AFP, FTP, WEBDAV), ALL for all protocol
#  Output:  a hash contains protocol is enabled (yes/no)
#  Example: getprotocolenabled(SMB);
#########################################################
sub getprotocolenabled {
	my($protocol) = @_;
	my %result;
	
	# get SMB
	if ($protocol eq "SMB" || $protocol eq "ALL") {
		open(my $IN, "$PRO_CONF_SMB");
		while (<$IN>) {
			$_ =~ s/\R//g;      # remove new line break
			$result{"SMB"} = "$_";
		}
		close($IN);
	}

	# get NFS
	if ($protocol eq "NFS" || $protocol eq "ALL") {
		open (my $IN, "$PRO_CONF_NFS");
		while (<$IN>) {
			$_ =~ s/\R//g;      # remove new line break
			$result{"NFS"} = "$_";
		}
		close($IN);
	}

	# get AFP
	if ($protocol eq "AFP" || $protocol eq "ALL") {
		open (my $IN, "$PRO_CONF_AFP");
		while (<$IN>) {
			$_ =~ s/\R//g;      # remove new line break
			$result{"AFP"} = "$_";
		}
		close($IN);
	}

	# get FTP
	if ($protocol eq "FTP" || $protocol eq "ALL") {
		open (my $IN, "$PRO_CONF_FTP");
		while (<$IN>) {
			$_ =~ s/\R//g;      # remove new line break
			$result{"FTP"} = "$_";
		}
		close($IN);
	}

	# get WEBDAV
	if ($protocol eq "WEBDAV" || $protocol eq "ALL") {
		open (my $IN, "$PRO_CONF_WEBDAV");
		while (<$IN>) {
			$_ =~ s/\R//g;      # remove new line break
			$result{"WEBDAV"} = "$_";
		}
		close($IN);
	}
	if ($protocol eq "keepalived" || $protocol eq "ALL") {
		open (my $IN, "$PRO_CONF_KEEPALIVED");
		while (<$IN>) {
			$_ =~ s/\R//g;      # remove new line break
			$result{"keepalived"} = "$_";
		}
		close($IN);
	}
	
	return %result;
}

#########################################################
#  Set to enable or disable input protocol
#  Input:   protocol name(SMB, NFS, AFP, FTP, WEBDAV), ALL for all protocol
#           YES / NO    enable(yes) or disable(no) protocol
#  Output:  0=OK
#  Example: setprotocolenabled(SMB, YES);
#########################################################
sub setprotocolenabled {
	my($protocol, $enable) = @_;
	my $isMaster = `$GETHISCTLRINFO_CMD -m`; chomp($isMaster);
	
	# set SMB
	if ($protocol eq "SMB" || $protocol eq "ALL") {
		if ($enable eq "YES") {
			open(my $OUT, ">$PRO_CONF_SMB");
			print $OUT "yes";
			close($OUT);
		}
		elsif ($enable eq "NO") {
			open(my $OUT, ">$PRO_CONF_SMB");
			print $OUT "no";
			close($OUT);
		}
		# check controller status to prevent overwrite each other
		if ($isMaster == 1) {
			my $realpath_conf = `$REALPATH_CMD $PRO_CONF_SMB 2>/dev/null`;
			chomp($realpath_conf);
			SyncFileToRemote("", "$realpath_conf");
		}
	}

	# set NFS
	if ($protocol eq "NFS" || $protocol eq "ALL") {
		if ($enable eq "YES") {
			open(my $OUT, ">$PRO_CONF_NFS");
			print $OUT "yes";
			close($OUT);
		}
		elsif ($enable eq "NO") {
			open(my $OUT, ">$PRO_CONF_NFS");
			print $OUT "no";
			close($OUT);
		}
		# check controller status to prevent overwrite each other
		if ($isMaster == 1) {
			my $realpath_conf = `$REALPATH_CMD $PRO_CONF_NFS 2>/dev/null`;
			chomp($realpath_conf);
			SyncFileToRemote("", "$realpath_conf");
		}
	}

	# set AFP
	if ($protocol eq "AFP" || $protocol eq "ALL") {
		if ($enable eq "YES") {
			open(my $OUT, ">$PRO_CONF_AFP");
			print $OUT "yes";
			close($OUT);
		}
		elsif ($enable eq "NO") {
			open(my $OUT, ">$PRO_CONF_AFP");
			print $OUT "no";
			close($OUT);
		}
		# check controller status to prevent overwrite each other
		if ($isMaster == 1) {
			my $realpath_conf = `$REALPATH_CMD $PRO_CONF_AFP 2>/dev/null`;
			chomp($realpath_conf);
			SyncFileToRemote("", "$realpath_conf");
		}
	}

	# set FTP
	if ($protocol eq "FTP" || $protocol eq "ALL") {
		if ($enable eq "YES") {
			open(my $OUT, ">$PRO_CONF_FTP");
			print $OUT "yes";
			close($OUT);
		}
		elsif ($enable eq "NO") {
			open(my $OUT, ">$PRO_CONF_FTP");
			print $OUT "no";
			close($OUT);
		}
		# check controller status to prevent overwrite each other
		if ($isMaster == 1) {
			my $realpath_conf = `$REALPATH_CMD $PRO_CONF_FTP 2>/dev/null`;
			chomp($realpath_conf);
			SyncFileToRemote("", "$realpath_conf");
		}
	}

	# set WEBDAV
	if ($protocol eq "WEBDAV" || $protocol eq "ALL") {
		if ($enable eq "YES") {
			open(my $OUT, ">$PRO_CONF_WEBDAV");
			print $OUT "yes";
			close($OUT);
		}
		elsif ($enable eq "NO") {
			open(my $OUT, ">$PRO_CONF_WEBDAV");
			print $OUT "no";
			close($OUT);
		}
		# check controller status to prevent overwrite each other
		if ($isMaster == 1) {
			my $realpath_conf = `$REALPATH_CMD $PRO_CONF_WEBDAV 2>/dev/null`;
			chomp($realpath_conf);
			SyncFileToRemote("", "$realpath_conf");
		}
	}

	if ($protocol eq "keepalived") {
		if ($enable eq "YES") {
			open(my $OUT, ">$PRO_CONF_KEEPALIVED");
			print $OUT "yes";
			close($OUT);
		}
		elsif ($enable eq "NO") {
			open(my $OUT, ">$PRO_CONF_KEEPALIVED");
			print $OUT "no";
			close($OUT);
		}
	}

	
	return 0;
}

########################################################################################################
#  Remove input iso Share Disk
#  Input:   sdname        iso Share Disk name(string)
#  Output:  0=OK, 1=input iso Share Disk does not exist, 2=unmount iso Share Disk failed
#  Example: del_iso_sharedisk("DVD");
########################################################################################################
sub del_iso_sharedisk {
	my ($sdname) = @_;
	
	my @sd_info = get_share_disk_info($sdname);
	my $is_exist = @sd_info;
	if ($is_exist == 0) {
		print "ISO Share Disk \"$sdname\" does not exist.\n";
		return 1;
	}
	my $mounted = $sd_info[0]->{"mounted"};
	
	if ($mounted == 1) {
		# make sure no proccess accessing this Share Disk
		kill_all_accessing_process("$SD_ISO_FOLDER/$sdname");
		my $res = system("$UNMOUNT_CMD -f -l $SD_ISO_FOLDER/$sdname");
		if ($res != 0) {
			print "unmount iso Share Disk \"$sdname\" failed.\n";
			return 2;
		}
	}
	if (-d "$SD_ISO_FOLDER/$sdname") {
		system("$RMDIR_CMD $SD_ISO_FOLDER/$sdname");
	}
	# remove from Share Disk table and also default permission as well
	delete_sd_db($sdname);
	
	# sync /nasdata/config/etc/fs.db
	SyncFileToRemote("", "$CONF_DB_FS");
	
	# remove all share protocol
	mark_reload_protocol("ALL");
		
	return 0;
}

########################################################################################################
#  Umount all iso Share Disk
#  Input:   -
#  Output:  0=OK, others=1 or more iso Share Disk umount failed.
#  Example: umount_all_iso_sharedisk();
########################################################################################################
sub umount_all_iso_sharedisk {
	my @sdinfo = get_share_disk_info();
	my $res = 0;
	
	for $info (@sdinfo) {
		if ($info->{"type"} eq $SD_TYPE_ISO) {
			my $mounted = $info->{"mounted"};
			my $sdname  = $info->{"sdname"};
			if ($mounted == 1) {
				# make sure no proccess accessing this Share Disk
				kill_all_accessing_process("$SD_ISO_FOLDER/$sdname");
				$res = system("$UNMOUNT_CMD -f -l $SD_ISO_FOLDER/$sdname");
				if ($res != 0) {
					print "unmount iso Share Disk \"$sdname\" failed.\n";
				}
				elsif (-d "$SD_ISO_FOLDER/$sdname") {
					system("$RMDIR_CMD $SD_ISO_FOLDER/$sdname");
				}
			}
		}
	}
	
	return $res;
}

########################################################################################################
#  Kill all process that accessing input path
#  Input:   path        folder or file path(string)
#  Output:  -
#  Example: kill_all_accessing_process("/SNAPSHOT/snapshot1");
########################################################################################################
sub kill_all_accessing_process {
	my ($path) = @_;
	my @pidarray;
	if($path=~/\/nasmnt\//){
		open(my $FUSER, "lsof $path |");
		while(<$FUSER>){
			if(/\S+\s+(\d+)/) {
				system("$KILL_CMD $1");
			}
		}
		close($FUSER);
		open(my $FUSER, "lsof $path |");
		while(<$FUSER>){
			if(/\S+\s+(\d+)/) {
				system("$KILL_CMD -9 $1");
			}
		}
		close($FUSER);
	}
	#Minging.Tsai. 2014/6/30. Prevent crond somehow been killed.
	#Just active it anyway.
	return 0;
}

########################################################################################################
#  Import protocol settings
#  Input:   export_dir        import file folder
#  Output:  -
#  Example: import_protocol_settings("/export/dir");
########################################################################################################
#Modify: Minging.Tsai. 2013/8/16. Modify import_protocol_settings for NAS gateway.
sub import_protocol_settings {
	my ($export_dir) = @_;
	
	chdir($export_dir);
	print "import configuration--\n";
	#import configuration
	copy_file_to_realpath("smb.conf",$SMB_CONF);
	copy_file_to_realpath("exports",$NFS_CONF);
	copy_file_to_realpath("helios.conf",$HELIOS_CONF);
	
	copy_file_to_realpath("nslcd.conf",$LDAP_NSLCD_CONF);
	copy_file_to_realpath("ldap.conf",$LDAP_CONF);
	copy_file_to_realpath("pam_ldap.conf",$LDAP_PAM_LDAP_CONF);

	copy_file_to_realpath("nsswitch.conf",$CONF_NSSWITCH);
	copy_file_to_realpath("resolv.conf",$CONF_RESOLV);
	copy_file_to_realpath("domain",$CONF_DOMAIN);

	
	#restore Share Disk setting and nfs allow ip setting
	my $fsdb = $export_dir."fs.db";
	# get import protocol setting
	my $querySQL  = "select sdname, defperm, smb_share, afp_share, ftp_share, nfs_share, webdav_share from SHARE_DISK where type <> 'hidden';";
	my $sqlfile = gen_random_filename("");
	open(my $OUT, ">$sqlfile");
	print $OUT ".separator \"\x4 : \x4\"\n";
	print $OUT "$querySQL\n";
	close($OUT);
	my $tmpfile = gen_random_filename("");
	my $dbres = exec_sqlfile($sqlfile, $tmpfile, $fsdb);
	if ($dbres != 0) {
		print "Get fsdb protocol setting error!\n";
		return $dbres;
	}	
	my @im_protocol_setting = ();
	open(my $IN, $tmpfile);
	while(<$IN>) {
		my @tempstr = split("\x4 : \x4", $_);
		if ($#tempstr == 6) {
			chomp($tempstr[6]); # chmop last field to avoid the value become "\n"
			push @im_protocol_setting, {"sdname" => $tempstr[0],
			                            "defperm" => $tempstr[1],
								        "smb_share" => $tempstr[2],
#										"afp_share" => $tempstr[3],
#								        "ftp_share" => $tempstr[4],
								        "nfs_share" => $tempstr[5]};
#								        "webdav_share" => $tempstr[6]};
		}
	}
	close($IN);
	unlink($tmpfile);
	# get import allow ip setting
	$querySQL  = "select sdname, group_concat(allow_ip) from NFS_ALLOW_IP group by sdname;";
	$sqlfile = gen_random_filename("");
	open($OUT, ">$sqlfile");
	print $OUT ".separator \"\x4 : \x4\"\n";
	print $OUT "$querySQL\n";
	close($OUT);
	$tmpfile = gen_random_filename("");
	$dbres = exec_sqlfile($sqlfile, $tmpfile, $fsdb);
	if ($dbres != 0) {
		print "Get fsdb allow ip setting error!\n";
		return $dbres;
	}
	my @im_allow_ip = ();
	open($IN, $tmpfile);
	while(<$IN>) {
		my @tempstr = split("\x4 : \x4", $_);
		if ($#tempstr == 1) {
			chomp($tempstr[1]); # chmop last field to avoid the value become "\n"
			push @im_allow_ip, {"sdname" => $tempstr[0],
			                    "allow_ip" => $tempstr[1]};
		}
	}
	close($IN);
	# get Share Disk info and only reserve mount Share Disk
	my @sdinfo = get_share_disk_info();
	my %mounted_sd = ();
	for $info (@sdinfo) {
		if ($info->{"mounted"} == 1) {
			my $sdname = $info->{"sdname"};
			my $mount_on = $info->{"mount_on"};
			$mounted_sd{"$sdname"} = "$mount_on";
		}
	}
		
	# update setting
	$sqlfile = gen_random_filename("");
	open($OUT, ">$sqlfile");
	print $OUT "BEGIN TRANSACTION;\n";
	for $im_setting (@im_protocol_setting) {
		my $im_sdname = $im_setting->{"sdname"};
		if(exists($mounted_sd{$im_sdname})) {
			my $im_defperm = $im_setting->{"defperm"};
	        my $im_smb_share = $im_setting->{"smb_share"};
#			my $im_afp_share = $im_setting->{"afp_share"};
#			my $im_ftp_share = $im_setting->{"ftp_share"};
			my $im_nfs_share = $im_setting->{"nfs_share"};
#			my $im_webdav_share = $im_setting->{"webdav_share"};
#			my $updateSQL = "update SHARE_DISK set defperm = $im_defperm, smb_share = $im_smb_share, afp_share = $im_afp_share, ";#Minging.Tsai.
			my $updateSQL = "update SHARE_DISK set defperm = $im_defperm, smb_share = $im_smb_share,  ";
#			$updateSQL   .= "ftp_share = $im_ftp_share, nfs_share = $im_nfs_share, webdav_share = $im_webdav_share where sdname = '$im_sdname';";#Minging.Tsai.
			$updateSQL   .= "nfs_share = $im_nfs_share,  where sdname = '$im_sdname';";
			print $OUT "$updateSQL\n";
		}
	}
	for $im_nfs_allow_ip (@im_allow_ip) {
		my $im_sdname = $im_nfs_allow_ip->{"sdname"};
		if(exists($mounted_sd{$im_sdname})) {
			print $OUT "delete from NFS_ALLOW_IP where sdname = '$im_sdname';\n";
			my $allow_ips = $im_nfs_allow_ip->{"allow_ip"};
			my @tempstr = split(",", $allow_ips);
			for $ip (@tempstr) {
				print $OUT "insert into NFS_ALLOW_IP (sdname, allow_ip) values ('$im_sdname', '$ip');\n";
			}
		}
	}
	print $OUT "COMMIT;\n";
	close($OUT);
	$dbres = exec_fs_sqlfile($sqlfile);
	if ($dbres != 0) {
		print "Set new protocol setting error!\n";
		return $dbres;
	}
	
	# sync /nasdata/config/etc/fs.db
	#SyncFileToRemote("", "$CONF_DB_FS");

	my %run_status = getprotocolstatus(ALL);
	my ($smb_im_state, $nfs_im_state);
	
	copy_file_to_realpath("smb",$PRO_CONF_SMB);
	open(my $SIN,"$PRO_CONF_SMB");
	while(<$SIN>) {
		$smb_im_state = $_;
		last;
	}
	close($SIN);
	chomp $smb_im_state;
	if(($smb_im_state eq "yes") && ($run_status{"SMB"} eq "OFF")){
		naslog($LOG_MISC_BACKUPRESTORE,$LOG_INFORMATION,"13","Importing samba status is enable and start samba.");
		startprotocol("SMB");
	}
	elsif(($smb_im_state eq "no") && ($run_status{"SMB"} eq "ON")){
		naslog($LOG_MISC_BACKUPRESTORE,$LOG_INFORMATION,"14","Importing samba status is disable and stop samba.");
		stopprotocol("SMB");
	}

	copy_file_to_realpath("nfs",$PRO_CONF_NFS);
	open($SIN,"$PRO_CONF_NFS");
	while(<$SIN>) {
		$nfs_im_state = $_;
		last;
	}
	close($SIN);
	chomp $nfs_im_state;
	if(($nfs_im_state eq "yes") && ($run_status{"NFS"} eq "OFF")){
		naslog($LOG_MISC_BACKUPRESTORE,$LOG_INFORMATION,"15","Importing NFS status is enable and start NFS.");
		startprotocol("NFS");
	}
	elsif(($nfs_im_state eq "no") && ($run_status{"NFS"} eq "ON")){
		naslog($LOG_MISC_BACKUPRESTORE,$LOG_INFORMATION,"16","Importing NFS status is disable and stop NFS.");
		stopprotocol("NFS");
	}

	
	
	return 0;
}

########################################################################################################
#  Set max connections to protocols, include SMB, FTP, HTTPD
#  Input:   $connection        (optional)max connections, set by system limitation if null
#  Output:  -
#  Example: set_protocol_max_connection(256);
########################################################################################################
sub set_protocol_max_connection {
	my ($connection) = @_;
	
	if (!defined($connection)) {
		my %limits = get_limits();
		$connection = $limits{"max_connections"};
	}
	
	my ($IN, $OUT);
	# set samba
	my $origin_smb = gen_random_filename("$SMB_CONF");
	my $smbtmp = gen_random_filename("$SMB_CONF");
	system("$CP_CMD -f $SMB_CONF $origin_smb");
	open($OUT, ">$smbtmp");
	open($IN, "<$origin_smb");
	while (<$IN>) {
		if (/^#/ || /^;/) {
			print $OUT "$_";
		}
		elsif (/max\s+connections\s+\=\s+(.*)/) {
			print $OUT "	max connections = $connection\n";
		}
		else {
			print $OUT "$_";
		}
	}
	close($IN);
	close($OUT);
	copy_file_to_realpath($smbtmp, $SMB_CONF);
	unlink($origin_smb);
	unlink($smbtmp);
	
	# set ftp
	my $origin_ftp = gen_random_filename("$FTP_CONF");
	my $ftptmp = gen_random_filename("$FTP_CONF");
	system("$CP_CMD -f $FTP_CONF $origin_ftp");
	open($OUT, ">$ftptmp");
	open($IN, "<$origin_ftp");
	while (<$IN>) {
		if (/MaxClients/) {
			print $OUT "MaxClients\t\t\t$connection\n";
		}
		else {
			print $OUT "$_";
		}
	}
	close($IN);
	close($OUT);
	copy_file_to_realpath($ftptmp, $FTP_CONF);
	unlink($origin_ftp);
	unlink($ftptmp);
	
	# set httpd
	my $origin_httpd = gen_random_filename("$APACHE_CONF");
	my $httpdtmp = gen_random_filename("$APACHE_CONF");
	system("$CP_CMD -f $APACHE_CONF $origin_httpd");
	open($OUT, ">$httpdtmp");
	open($IN, "<$origin_httpd");
	while (<$IN>) {
		if (/ServerLimit/) {
			# print nothing
		}
		elsif (/MaxClients/) {
			if ($connection > 256) {
				print $OUT "ServerLimit $connection\n";
			}
			print $OUT "MaxClients $connection\n";
		}
		else {
			print $OUT "$_";
		}
	}
	close($IN);
	close($OUT);
	copy_file_to_realpath($httpdtmp, $APACHE_CONF);
	unlink($origin_httpd);
	unlink($httpdtmp);
	
	return 0;
}

########################################################################################################
#  Stop all protocol without changing enable flag
#  Input:   -
#  Output:  0=OK, other=one or more protocol stopping failed
#  Example: stop_all_protocol();
########################################################################################################
sub stop_all_protocol {
	my $res = 0;
	# stop samba
	$res += system("$SERVICE_CMD smb stop >/dev/null 2>/dev/null");
	# stop nfs
	$res += system("$SERVICE_CMD unfsd stop >/dev/null 2>/dev/null");
	# stop keepalived
	$res += system("$SERVICE_CMD keepalived stop >/dev/null 2>/dev/null");
	# stop afp
#	$res += system("$SERVICE_CMD netatalk stop >/dev/null 2>/dev/null");
	# stop ftp
#	$res += system("$SERVICE_CMD ftp stop >/dev/null 2>/dev/null");
	# stop httpd
#	$res += system("$SERVICE_CMD httpd stop >/dev/null 2>/dev/null");
	
	return $res;
}
sub get_cache_info {
	$nfs_option = "";
	$smb_option = "";
	my %cache;
	my @cont = ();
	open(my $IN, "/etc/unfsd.conf");
	while(<$IN>) {
		if(/inner_cache=(\d+)/) {
			$nfs_option = $1;
			last;
		}
	}
	close($IN);
	$cache{"NFS"} = $nfs_option;

	open(my $IN, "/etc/samba/smb.conf");
	while(<$IN>) {
		if(/enable RB cache\s*=\s*(\S+)/) {
			$smb_option = $1;
			last;
		}
	}
	close($IN);
	if($smb_option eq "yes") {
		$smb_option = 1;
	} else {
		$smb_option = 0;
	}
	$cache{"SMB"} = $smb_option;

	return %cache;
}

return 1;
