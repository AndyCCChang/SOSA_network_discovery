#!/usr/bin/perl
#########################################################################################################
#   (C) Copyright Promise Technology Inc., 2012 All Rights Reserved                                     #
#  Name: bk_replication_lib.pl                                                                          #
#  Author: Kinix                                                                                        #
#  Date: 2012/10/22                                                                                     #
#  Description: This perl is some sub routines for replication or it's recovery.                        #
#               GetReplicationShareDiskStatus                                                           #
#               GetReplicationTaskShareDiskStatus                                                       #
#               GetRecoveryShareDiskStatus                                                              #
#               GetRemoteMounteOn                                                                       #
#               SwitchBack                                                                              #
#########################################################################################################
require "/nasapp/perl/lib/cmd_path.pl";        #$MOUNT_CMD, $FUSER_CMD, $MXARGS_CMD, $KILL_CMD, $UNMOUNT_CMD, $MKDIR_CMD, $MOUNT_GFS2_CMD, $MOUNT_GFS2_OPT, $RM_CMD
require "/nasapp/perl/lib/fs_lib.pl";          #$SD_TYPE_STANDARD, $SD_TYPE_CLUSTER, $SD_FS_FOLDER, get_share_disk_info
require "/nasapp/perl/lib/bk_def.pl";
require "/nasapp/perl/lib/bk_browse_lib.pl";   #GetRemoteShareDiskConnection, GetShareDiskUsedAvailable, GetRemoteShareDiskUsedAvailable
require "/nasapp/perl/lib/bk_task_lib.pl";     #ReadConfigFile
require "/nasapp/perl/lib/bk_ssh_lib.pl";      #GetConnectionLocalIP, SSHSystem, RemoveSSHPublicKeyFromRemote

###############################################################################
# Get replication Share Disk status include all Share Disks at local          #
#   Input:                                                                    #
#           $_[0]: server site                                                #
#           $_[1]: ssh switch                                                 #
#           $_[2]: port                                                       #
#           $_[3]: Share Disk info                                            #
#   Output:                                                                   #
#           $_[4]: array of hash table                                        #
#                  sdname      => Share Disk name                             #
#                  localState  => Local Share Disk state,                     #
#                                   1=Ready, 0=Not ready, 2=No Share Disk     #
#                  remoteState => Remote Share Disk state,                    #
#                                   1=Ready, 0=Not ready,                     #
#                                   2=Share Disk size too small               #
#                  checked     => Replication setting,                        #
#                                   1=Do replication, 0=Don't do replication  #
#   Return:                                                                   #
#           0 success                                                         #
#           5 Remote site not ready                                           #
###############################################################################
sub GetReplicationShareDiskStatus
{
	my $server = shift;
	my $sshswitch = shift;
	my $port = shift;
	my $shareDiskInfo = shift;
	my $output = shift;
	my $result = 0;

	@$output = ();
	# Get task Share Disk list
	my $taskShareDiskList;
	my $confFile = "$BK_REPLICATION_PREFIX/$server/$BK_TASK_CONFFILE";
	if(-f $confFile) {
		ReadConfigFile($confFile, "", "", \$taskShareDiskList, "", "", "", "", "", "", "", "");
	}
	my @taskShareDisks = split(/,/, $taskShareDiskList);

	# Check for local Share Disks
	for(my $i=0; $i<scalar(@$shareDiskInfo); $i++) {
		next if(${@$shareDiskInfo[$i]}{'type'} ne $SD_TYPE_STANDARD && ${@$shareDiskInfo[$i]}{'type'} ne $SD_TYPE_CLUSTER);
		### check remote Share Disk state ###
		my $shareDisk = ${@$shareDiskInfo[$i]}{'sdname'};
		$result = GetRemoteShareDiskConnection($server, $shareDisk, $sshswitch, $port);
		last if($result == 5);
		my $remoteState = "0";
		$remoteState = "1" if($result == 0);
		### check remote Share Disk size ###
		my $localState = ${@$shareDiskInfo[$i]}{'mounted'};
		my $localUsed;
		GetShareDiskUsedAvailable($shareDisk, \$localUsed, "");
		my $remoteUsed, $remoteAvailable, $remoteTotal;
		GetRemoteShareDiskUsedAvailable($server, $shareDisk, \$remoteUsed, \$remoteAvailable);
		$remoteTotal = $remoteUsed + $remoteAvailable;
		$remoteState = "2" if($remoteTotal > 0 &&  $remoteTotal < $localUsed);
		### check Share Disk is in list or not ###
		my $checked = "0";
		foreach(@taskShareDisks) {
			if($shareDisk eq $_) {
				$checked = "1";
				last;
			}
		}
		push @$output, {"sdname"=>$shareDisk, "localState"=>$localState, "remoteState"=>$remoteState, "checked"=>$checked};
		print "$shareDisk\t\tLocal:$localState\t\tRemote:$remoteState\t\tChecked:$checked\n";
	}
	# Check for task Share Disks do not appear in local Share Disks
	if($result != 5) {
		foreach(@taskShareDisks) {
			my $taskShareDisk = $_;
			my $found = 0;
			for(my $i=0; $i<scalar(@$shareDiskInfo); $i++) {
				if(${@$shareDiskInfo[$i]}{'sdname'} eq $taskShareDisk) {
					$found = 1;
					last;
				}
			}
			if(0 == $found) {
				$result = GetRemoteShareDiskConnection($server, $taskShareDisk, $sshswitch, $port);
				my $remoteState = "0";
				$remoteState = "1" if($result == 0);
				push @$output, {"sdname"=>$taskShareDisk, "localState"=>"2", "remoteState"=>$remoteState, "checked"=>"1"};
				print "$taskShareDisk\t\tLocal:2\t\tRemote:$remoteState\t\tChecked:1\n";
			}
		}
	}
	@$output = sort{uc($a->{'sdname'}) cmp uc($b->{'sdname'})}(@$output);
	return $result if($result == 5);
	return 0;
}


############################################################
# Get replication task Share Disk status                   #
#   Input:                                                 #
#           $_[0]: server site                             #
#           $_[1]: ssh switch                              #
#           $_[2]: port                                    #
#           $_[3]: Share Disk info                         #
#   Output:                                                #
#           $_[4]: array of hash table                     #
#                  sdname      => Share Disk name          #
#                  localState  => Local Share Disk state,  #
#                                   1=Ready, 0=Not ready   #
#                  remoteState => Remote Share Disk state, #
#                                   1=Ready, 0=Not ready   #
#   Return:                                                #
#           0 Success                                      #
#           5 Remote site not ready                        #
#           7 One of the remote Share Disk                 #
#             has not enough space to do replication       #
############################################################
sub GetReplicationTaskShareDiskStatus
{
	my $server = shift;
	my $sshswitch = shift;
	my $port = shift;
	my $shareDiskInfo = shift;
	my $output = shift;
	my $result = 0;

	@$output = ();
	# Get task Share Disk list
	my $taskShareDiskList;
	my $confFile = "$BK_REPLICATION_PREFIX/$server/$BK_TASK_CONFFILE";
	if(-f $confFile) {
		ReadConfigFile($confFile, "", "", \$taskShareDiskList, "", "", "", "", "", "", "", "");
	}
	my @taskShareDisks = split(/,/, $taskShareDiskList);

	# Check for local Share Disks
	for(my $i=0; $i<scalar(@$shareDiskInfo); $i++) {
		my $shareDisk = ${@$shareDiskInfo[$i]}{'sdname'};
		my $remoteConn = GetRemoteShareDiskConnection($server, $shareDisk, $sshswitch, $port);
		if($remoteConn == 5) {
			$result = $remoteConn;
			last;
		}
		my $remoteState = "0";
		$remoteState = "1" if($remoteConn == 0);
		my $localState = ${@$shareDiskInfo[$i]}{'mounted'};
		my $checked = "0";
		foreach(@taskShareDisks) {
			if($shareDisk eq $_) {
				$checked = "1";
				last;
			}
		}
		next if($checked ne "1");
		### Check local and remote Share Disk used and available size ###
		my $localUsed;
		GetShareDiskUsedAvailable($shareDisk, \$localUsed, "");
		my $remoteUsed, $remoteAvailable, $remoteTotal;
		GetRemoteShareDiskUsedAvailable($server, $shareDisk, \$remoteUsed, \$remoteAvailable);
		$remoteTotal = $remoteUsed + $remoteAvailable;
		$result = 7 if($remoteTotal > 0 &&  $remoteTotal < $localUsed);
		push @$output, {"sdname"=>$shareDisk, "localState"=>$localState, "localUsed"=>$localUsed,
				"remoteState"=>$remoteState, "remoteTotal"=>$remoteTotal};
		print "$shareDisk\t\tLocal:Used:$localUsed MB,$localState\t\tRemote:Total:$remoteTotal MB,$remoteState\n";
	}
	@$output = sort{uc($a->{'sdname'}) cmp uc($b->{'sdname'})}(@$output);
	return $result;
}


#####################################################################
# Get recovery Share Disk status, only show replication Share Disks #
#   Input:                                                          #
#           $_[0]: server site                                      #
#           $_[1]: Share Disk info                                  #
#   Output:                                                         #
#           $_[2]: array of hash table                              #
#                  sdname        => Share Disk name                 #
#                  localState    => Local Share Disk state,         #
#                                   1=Ready, 0=Not ready            #
#                  remoteState   => Remote Share Disk state,        #
#                                   1=Ready, 0=Not ready            #
#                  localMountOn  => Local Share Disk                #
#                                   /dev/mapper/$vgname-$lvname     #
#                                   mount on Path                   #
#                  RemoteMountOn => Remote IP which mounting on     #
#                                   $SD_FS_FOLDER/$shareDisk        #
#   Return:                                                         #
#           0 success                                               #
#           1 error                                                 #
#           5 Remote site not ready                                 #
#####################################################################
sub GetRecoveryShareDiskStatus
{
	my $server = shift;
	my $shareDiskInfo = shift;
	my $output = shift;
	my $result = 0;

	@$output = ();
	# Get task Share Disk list
	my $taskShareDiskList, $sshswitch, $port;
	my $confFile = "$BK_REPLICATION_PREFIX/$server/$BK_TASK_CONFFILE";
	if(ReadConfigFile($confFile, "", "", \$taskShareDiskList, "", "", \$sshswitch, \$port, "", "", "", "") != 0) {
		print "Error: Read configure file error!\n";
		return 1;
	}
	my @taskShareDisks = split(/,/, $taskShareDiskList);

	# Check for task Share Disks
	foreach(@taskShareDisks) {
		my $taskShareDisk = $_;
		my $localState = "0";
		my $localMountOn = "";
		for(my $i=0; $i<scalar(@$shareDiskInfo); $i++) {
			if(${@$shareDiskInfo[$i]}{'sdname'} eq $taskShareDisk) {
				$localState = "1";
				$localMountOn = ${@$shareDiskInfo[$i]}{'mount_on'};
				last;
			}
		}
		my $remoteState = "0";
		$remoteState = "1" if(GetRemoteShareDiskConnection($server, $taskShareDisk, $sshswitch, $port) == 0);
		my $remoteMountOn = GetRemoteMounteOn($taskShareDisk);
		push @$output, {"sdname"=>$taskShareDisk, "localState"=>$localState, "remoteState"=>$remoteState,
						"localMountOn"=>$localMountOn, "remoteMountOn"=>$remoteMountOn};
		print "$taskShareDisk\t\tLocal:$localState\tRemote:$remoteState\tLocalMountOn:$localMountOn\t\tRemoteMountOn:$remoteMountOn\n";
	}
	@$output = sort{uc($a->{'sdname'}) cmp uc($b->{'sdname'})}(@$output);
	return $result;
}


################################################
# Get the remote IP address that               #
#     $SD_FS_FOLDER/$shareDisk is mounted      #
#   Input:                                     #
#           $_[0]: Share Disk name             #
#   Return:                                    #
#           IP address that remote mount on    #
################################################
sub GetRemoteMounteOn
{
	my $shareDisk = shift;
	my $result = "";

	open(my $IN, "$MOUNT_CMD |");
	while(<$IN>) {
		if(/(.+)\:$SD_FS_FOLDER\/$shareDisk\s+on\s+$SD_FS_FOLDER\/$shareDisk\s+type\s+nfs/) {
			$result = "$1";
			last;
		}
	}
	close($IN);
	return $result;
}


##############################################
# Switch back Share Disk                     #
#   Input:                                   #
#           $_[0]: Share Disk name           #
#           $_[1]: force umount, 1 or 0      #
#   Return:                                  #
#           0=success,                       #
#           1=device is busy,                #
#           3=recovery is still running,     #
#           4=umount remote Share Disk fail, #
#           5=umount local Share Disk fail,  #
#           6=mount local Share Disk fail    #
##############################################
sub SwitchBack
{
	my $shareDisk = shift;
	my $forceUmount = shift;

	if(-f "$RECOVERY_PREFIX/$shareDisk.pid") {
		print "Error: Recovery is running!\n";
		return 3;
	}

	#Get Share Disk information and check local and remote Share Disk states
	my @shareDiskInfo = get_share_disk_info();
	my $localState, $remoteState, $localMountOn, $remoteMountOn;
	# Get remote state
	$remoteMountOn = GetRemoteMounteOn($shareDisk);
	if ($remoteMountOn ne "") {
		my $sshswitch, $port;
		my $confFile = "$BK_REPLICATION_PREFIX/$remoteMountOn/$BK_TASK_CONFFILE";
		if(ReadConfigFile($confFile, "", "", "", "", "", \$sshswitch, \$port, "", "", "", "") == 0) {
			if(GetRemoteShareDiskConnection($remoteMountOn, $shareDisk, $sshswitch, $port) == 0) {
				$remoteState = "1";
			}
		}
	}
	# Get local state
	for(my $i=0; $i<scalar(@shareDiskInfo); $i++) {
		if(${@shareDiskInfo[$i]}{'sdname'} eq $shareDisk) {
			$localState = "1";
			$localMountOn = ${@shareDiskInfo[$i]}{'mount_on'};
			last;
		}
	}

	#Final sync and check remote Share Disk and local recovery Share Disk unmountable
	if($localState eq "1" && $remoteState eq "1" &&
			$localMountOn eq "$RECOVERY_PREFIX/$shareDisk" && $remoteMountOn ne "") {
		#Final sync without switch back part
		print "Final sync...\n";
		system("$PL_BKRSYNCRECOVERY $shareDisk");
		print "done!\n";

		#Check remote Share Disk and local recovery Share Disk unmountable
		if($forceUmount != 1) {
			my $umountable = 1;
			open(my $FUSER, "$FUSER_CMD -m $SD_FS_FOLDER/$shareDisk $RECOVERY_PREFIX/$shareDisk |");
			$umountable = 0 if(<$FUSER>);
			close($FUSER);
			#if isn't umountable wait for next time
			if(0 == $umountable) {
				my $counter = 0;
				my $swbFile = "$RECOVERY_PREFIX/$shareDisk.swb";
				if(-f $swbFile) {
					open(my $IN, "< $swbFile");
					$counter = <$IN>;
					close($IN);
				}
				if($counter < $RECOVERY_SWB_MAX) {
					$counter ++;
					open(my $OUT, "> $swbFile");
					print $OUT "$counter";
					close($OUT);
					print "Device busy! Counter:$counter\n";
					return 1;
				}
			}
		}
	}

	#Umount remote Share Disk
	if($remoteMountOn ne "") {
		print "Umount remote Share Disk from $SD_FS_FOLDER/$shareDisk...";
		$result = system("$FUSER_CMD -m $SD_FS_FOLDER/$shareDisk | $MXARGS_CMD $KILL_CMD -9; $UNMOUNT_CMD -f -l $SD_FS_FOLDER/$shareDisk");
		if($result != 0) {
			print "failed!\n";
			return 4;
		}
		my $localIP = GetConnectionLocalIP($remoteMountOn);
		if($localIP eq "") {
			for(my $retry = 3; $localIP eq "" && $retry >= 0; $retry--) {
				$localIP = GetConnectionLocalIP($remoteMountOn);
			}
		}
		if($localIP ne "") {
			SSHSystem($remoteMountOn, "$PL_PRONFSEXPORTS remove \"$SD_FS_FOLDER/$shareDisk\" \"$localIP\"");
		}
		print "done!\n";
	}

	#Umount local recovery Share Disk
	if($localMountOn eq "$RECOVERY_PREFIX/$shareDisk") {
		print "Umount local Share Disk from $RECOVERY_PREFIX/$shareDisk...";
		$result = system("$FUSER_CMD -m $RECOVERY_PREFIX/$shareDisk | $MXARGS_CMD $KILL_CMD -9; $UNMOUNT_CMD -f -l $RECOVERY_PREFIX/$shareDisk");
		if($result != 0) {
			print "failed!\n";
			return 5;
		}
		print "done!\n";
	}

	#Mount local Share Disk on $SD_FS_FOLDER/$shareDisk
	if($localMountOn ne "$SD_FS_FOLDER/$shareDisk") {
		print "Mount local Share Disk on $SD_FS_FOLDER/$shareDisk...";
		my $vgName = "", $lvName = "";
		for $href (@shareDiskInfo) {
			if($href->{'sdname'} eq $shareDisk) {
				$vgName = $href->{'vgname'};
				$lvName = $href->{'lvname'};
				last;
			}
		}
		if($vgName eq "" || $lvName eq "") {
			print "\nError: Mount $shareDisk on $SD_FS_FOLDER/$shareDisk failed!\n";
			return 6;
		}
		$result = system("$MKDIR_CMD -p $SD_FS_FOLDER/$shareDisk;$MOUNT_GFS2_CMD $MOUNT_GFS2_OPT /dev/mapper/$vgName-$lvName $SD_FS_FOLDER/$shareDisk");
		if($result != 0) {
			print "\nError: Mount /dev/mapper/$vgName-$lvName on $SD_FS_FOLDER/$shareDisk failed!\n";
			return 6;
		}
		print "done!\n";
	}

	#Remove useless files
	system("$RM_CMD -rf $RECOVERY_PREFIX/$shareDisk*");
	RemoveSSHPublicKeyFromRemote($remoteMountOn) if($remoteMountOn ne "");
	return 0;
}

