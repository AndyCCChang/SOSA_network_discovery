#!/usr/bin/perl
#########################################################################################################
#   (C) Copyright Promise Technology Inc., 2012 All Rights Reserved                                     #
#  Name: bk_server_lib.pl                                                                               #
#  Author: Kinix                                                                                        #
#  Date: 2013/03/13                                                                                     #
#  Description: This perl is some sub routines for backup server settings.                              #
#               RestartSSHDaemon                                                                        #
#               RestartRsyncDaemon                                                                      #
#               SetSSHDPort                   <-  RestartSSHDaemon                                      #
#               GetSSHDPort                                                                             #
#               SetRsyncdPort                 <-  GetRsyncdConfFilePath, RestartRsyncDaemon             #
#               GetRsyncdPort                 <-  GetRsyncdConfFilePath                                 #
#               GetShareDiskMountPath                                                                   #
#               RemoveRsyncServerByShareDisk  <-  GetRsyncdConfFilePath                                 #
#               RefineRsyncdConfFile          <-  GetRsyncdConfFilePath                                 #
#               RsyncServerRenameShareDisk    <-  GetShareDiskMountPath, GetRsyncdConfFilePath          #
#               GetRsyncdConfFilePath                                                                   #
#########################################################################################################
require "/nasapp/perl/lib/common.pl";        #gen_random_filename
require "/nasapp/perl/lib/cmd_path.pl";      #$SSHD_CMD, $TASKSET_CMD, $CAT_CMD, $MXARGS_CMD, $KILL_CMD, $RSYNC_CMD, $CP_CMD, $LN_CMD, $RM_CMD, $GETHISCTLRINFO_CMD
require "/nasapp/perl/lib/conf_path.pl";     #$SSHD_PID, $RSYNCD_PID, $DATA_PATH, $SSHD_CONF, $RSYNCD_CONF
require "/nasapp/perl/lib/fs_lib.pl";        #get_share_disk_info
require "/nasapp/perl/lib/bk_def.pl";
require "/nasapp/perl/lib/bk_ssh_lib.pl";    #SyncFileToRemote

######################
# Restart ssh daemon #
######################
sub RestartSSHDaemon
{
	my $command = "$SSHD_CMD";
	$command = "$TASKSET_CMD -c $CPU_CORE_BACKUP_SERVER ".$command if($CPU_CORE_BACKUP_SERVER ne "");
	$command = "$CAT_CMD $SSHD_PID | $MXARGS_CMD $KILL_CMD -HUP;sleep 1;".$command if(-f $SSHD_PID);
	system($command);
}


########################
# Restart rsync daemon #
########################
sub RestartRsyncDaemon
{
	my $command = "$RSYNC_CMD --daemon";
	$command = "$TASKSET_CMD -c $CPU_CORE_BACKUP_SERVER ".$command if($CPU_CORE_BACKUP_SERVER ne "");
	$command = "$CAT_CMD $RSYNCD_PID | $MXARGS_CMD $KILL_CMD -HUP;sleep 1;".$command if(-f $RSYNCD_PID);
	system($command);
}


##############################
# Set ssh daemon port        #
#   Input:                   #
#           $_[0]: sshd port #
#   Return:                  #
#           0:Didn't modify  #
#           1:Modified       #
##############################
sub SetSSHDPort
{
	my $sshdPort = shift;
	my $sshdConf = "$DATA_PATH$SSHD_CONF";
	my $inSSHDConf = gen_random_filename();
	my $outSSHDConf = gen_random_filename();
	my $restart = 0;
	$sshdPort = $BK_SSHD_PORT if($sshdPort eq "");
	system("$CP_CMD -af \"$sshdConf\" \"$inSSHDConf\"");
	open(my $OUT, "> $outSSHDConf");
	open(my $IN, "< $inSSHDConf");
	while(<$IN>) {
		if(/Port\s+(\d*)\s+\#backup server/) {
			my $port = $1;
			$restart = 1 if($port ne $sshdPort);
			print $OUT "Port $sshdPort \t#backup server\n";
		}
		else {
			print $OUT "$_";
		}
	}
	close($IN);
	close($OUT);
	unlink($inSSHDConf);
	if($restart != 0) {
		system("$CP_CMD -af \"$outSSHDConf\" \"$sshdConf\"");
		SyncFileToRemote("", $sshdConf);
		RestartSSHDaemon();
	}
	unlink($outSSHDConf);
	return $restart;
}


###############################
# Get ssh daemon port setting #
#   Output:                   #
#           $_[0]: sshd port  #
###############################
sub GetSSHDPort
{
	my $sshdPort = shift;
	$$sshdPort = "" if($sshdPort ne "");

	my $sshdConf = "$DATA_PATH$SSHD_CONF";
	my $inSSHDConf = gen_random_filename();
	system("$CP_CMD -af \"$sshdConf\" \"$inSSHDConf\"");
	open(my $IN, "< $inSSHDConf");
	while(<$IN>) {
		if($sshdPort ne "" && /Port\s+(\d*)\s+\#backup server/) {
			$$sshdPort = $1;
			last;
		}
	}
	close($IN);
	unlink($inSSHDConf);
}


################################
# Set rsync daemon port        #
#   Input:                     #
#           $_[0]: rsyncd port #
#   Return:                    #
#           0:Didn't modify    #
#           1:Modified         #
################################
sub SetRsyncdPort
{
	my $rsyncdPort = shift;
	my $rsyncdConf = GetRsyncdConfFilePath();
	my $inRsyncdConf = gen_random_filename();
	my $outRsyncdConf = gen_random_filename();
	my $restart = 0;
	$rsyncdPort = $BK_RSYNCD_PORT if($rsyncdPort eq "");
	system("$CP_CMD -af \"$rsyncdConf\" \"$inRsyncdConf\"");
	open(my $OUT, "> $outRsyncdConf");
	open(my $IN, "< $inRsyncdConf");
	while(<$IN>) {
		if(/port=(\d*)/) {
			my $port = $1;
			$restart = 1 if($port ne $rsyncdPort);
			print $OUT "port=$rsyncdPort\n";
		}
		else {
			print $OUT "$_";
		}
	}
	close($IN);
	close($OUT);
	unlink($inRsyncdConf);
	if($restart != 0) {
		system("$CP_CMD -af \"$outRsyncdConf\" \"$rsyncdConf\"");
		system("$LN_CMD -sf $rsyncdConf $RSYNCD_CONF");
		SyncFileToRemote("", $rsyncdConf);
		RestartRsyncDaemon();
	}
	unlink($outRsyncdConf);
	return $restart;
}


###############################
# Get rsync daemon port       #
#   Output:                   #
#           $_[0]: rsync port #
###############################
sub GetRsyncdPort
{
	my $rsyncdPort = shift;
	$$rsyncdPort = "" if($rsyncdPort ne "");

	my $rsyncdConf = GetRsyncdConfFilePath();
	my $inRsyncdConf = gen_random_filename();
	system("$CP_CMD -af \"$rsyncdConf\" \"$inRsyncdConf\"");
	open(my $IN, "< $inRsyncdConf");
	while(<$IN>) {
		if($rsyncdPort ne "" && /port=(\d*)/) {
			$$rsyncdPort = $1;
			last;
		}
	}
	close($IN);
	unlink($inRsyncdConf);
}


####################################
# Get Share Disk mount path        #
#   Input:                         #
#           $_[0]: Share Disk name #
####################################
sub GetShareDiskMountPath
{
	my $shareDisk = shift;
	my $path = "";
	my @shareDiskList = get_share_disk_info();
	for($i=0; $i<scalar(@shareDiskList); $i++) {
		if(${@shareDiskList[$i]}{'sdname'} eq $shareDisk) {
			$path = ${@shareDiskList[$i]}{'mount_on'};
			last;
		}
	}
	return $path;
}


#################################################
# Remove Share Disk rsync backup server setting #
#   Input:                                      #
#           $_[0]: Share Disk name              #
#################################################
sub RemoveRsyncServerByShareDisk
{
	my $shareDisk = shift;
	my $match = 0;
	my $pass = 0;
	my $rsyncdConf = GetRsyncdConfFilePath();
	my $inRsyncdConf = gen_random_filename();
	my $outRsyncdConf = gen_random_filename();
	system("$CP_CMD -af \"$rsyncdConf\" \"$inRsyncdConf\"");
	open(my $OUT, "> $outRsyncdConf");
	open(my $IN, "< $inRsyncdConf");
	while(<$IN>) {
		if(/\[$shareDisk\]/i) {
			$match = 1;
			$pass = 1;
		}
		elsif($_ eq "comment=$BK_SERVER_COMMENT\n" && 1 == $match) {
			$match = 2;
		}
		elsif($_ eq "\n" && 1 == $pass) {
			if(2 != $match) {
				$match = 0;
			}
			$pass = 0;
		}
		elsif(0 == $pass) {
			print $OUT "$_";
		}
	}
	close($IN);
	close($OUT);
	unlink($inRsyncdConf);
	if(2 == $match) {
		unlink("$SSHRSYNC_PREFIX/$shareDisk");
		system("$CP_CMD -af \"$outRsyncdConf\" \"$rsyncdConf\"");
		SyncFileToRemote("", $rsyncdConf);
	}
	system("$LN_CMD -sf $rsyncdConf $RSYNCD_CONF");
	unlink($outRsyncdConf);
}


######################################################
# RefineRsyncdConfFile                               #
#   Clear all inexistent Share Disk from rsyncd.conf #
#   Return:                                          #
#           0:Didn't modify                          #
#           1:Modified                               #
######################################################
sub RefineRsyncdConfFile
{
	my $buff = "";
	my $shareDisk = "";
	my $match = 0;
	my $pass = 0;
	my $result = 0;
	
	### Get current Share Disk status ###
	my $i;
	my %hashSD;
	my @shareDiskInfo = get_share_disk_info();
	for($i=0; $i<scalar(@shareDiskInfo); $i++) {
		$hashSD{${@shareDiskInfo[$i]}{'sdname'}} = ${@shareDiskInfo[$i]}{'mount_on'};
	}

	### Check rsyncd.conf ###
	mkdir $SSHRSYNC_PREFIX;
	my $rsyncdConf = GetRsyncdConfFilePath();
	my $inRsyncdConf = gen_random_filename();
	my $outRsyncdConf = gen_random_filename();
	system("$CP_CMD -af \"$rsyncdConf\" \"$inRsyncdConf\"");
	open(my $OUT, "> $outRsyncdConf");
	open(my $IN, "< $inRsyncdConf");
	while(<$IN>) {
		if(/\[(.+)\]/) {
			$shareDisk = $1;
			$match = 1;
			$pass = 1;
			$buff = $_;
		}
		elsif($_ eq "comment=$BK_SERVER_COMMENT\n" && 1 == $match) {
			$match = 2;
			if($hashSD{$shareDisk} ne "") {
				$pass = 0;
				print $OUT $buff.$_;
				system("$LN_CMD -snf $hashSD{$shareDisk} \"$SSHRSYNC_PREFIX/$shareDisk\"");
			}
			else {
				$result = 1;
				system("$RM_CMD -f \"$SSHRSYNC_PREFIX/$shareDisk\"");
			}
			$buff = "";
		}
		elsif($_ eq "\n" && 1 == $pass) {
			print $OUT $buff.$_ if($match != 2);
			$match = 0;
			$pass = 0;
			$buff = "";
		}
		elsif($match != 2 && 1 == $pass) {
			$buff = $buff.$_;
		}
		elsif(0 == $pass) {
			print $OUT "$_";
		}
	}
	close($OUT);
	close($IN);
	unlink($inRsyncdConf);
	if($result == 1) {
		system("$CP_CMD -af \"$outRsyncdConf\" \"$rsyncdConf\"");
		SyncFileToRemote("", $rsyncdConf);
	}
	system("$LN_CMD -sf $rsyncdConf $RSYNCD_CONF");
	unlink($outRsyncdConf);
	return $result;
}


#######################################################
# RsyncServerRenameShareDisk                          #
#   Modify rsyncd.conf for Share Disk name is changed #
#   Input:                                            #
#           $_[0]: Old Share Disk name                #
#           $_[1]: New Share Disk name                #
#   Return:                                           #
#           0:Didn't modify                           #
#           1:Modified                                #
#######################################################
sub RsyncServerRenameShareDisk
{
	my $oldName = shift;
	my $newName = shift;
	my $path = GetShareDiskMountPath($newName);
	my $newHeader = "[$newName]\npath=$path\n";

	my $oldBody = "";
	my $buff = "";
	my $match = 0;
	my $pass = 0;
	my $result = 0;
	my $rsyncdConf = GetRsyncdConfFilePath();
	my $inRsyncdConf = gen_random_filename();
	my $outRsyncdConf = gen_random_filename();
	system("$CP_CMD -af \"$rsyncdConf\" \"$inRsyncdConf\"");
	open(my $OUT, "> $outRsyncdConf");
	open(my $IN, "< $inRsyncdConf");
	while(<$IN>) {
		if(/\[$oldName\]/i) {
			$match = 1;
			$pass = 1;
			$buff = $_;
		}
		elsif(/path=.+\n/ && 1 == $pass) {
			$buff = $buff.$_;
		}
		elsif($_ eq "comment=$BK_SERVER_COMMENT\n" && 1 == $match) {
			$match = 2;
			$result = 1;
			$oldBody = $oldBody.$_;
		}
		elsif($_ eq "\n" && 1 == $pass) {
			if($match != 2) {
				print $OUT $buff.$_;
			}
			else {
				print $OUT $newHeader.$oldBody."\n";
			}
			$match = 0;
			$pass = 0;
			$buff = "";
			$oldBody = "";
		}
		elsif(1 == $pass) {
			$buff = $buff.$_ if($match != 2);
			$oldBody = $oldBody.$_;
		}
		elsif(0 == $pass) {
			print $OUT "$_";
		}
	}
	close($OUT);
	close($IN);
	unlink($inRsyncdConf);
	mkdir $SSHRSYNC_PREFIX;
	if($result == 1) {
		system("$CP_CMD -af \"$outRsyncdConf\" \"$rsyncdConf\"");
		SyncFileToRemote("", $rsyncdConf);
		unlink("$SSHRSYNC_PREFIX/$oldName");
		system("$LN_CMD -sn $path \"$SSHRSYNC_PREFIX/$newName\"") if($path ne "");
	}
	system("$LN_CMD -sf $rsyncdConf $RSYNCD_CONF");
	unlink($outRsyncdConf);
	return $result;
}


##################################
# Get rsyncd configure file path #
##################################
sub GetRsyncdConfFilePath
{
	my $role = `$GETHISCTLRINFO_CMD -m`; chomp($role);
	return "$DATA_PATH$RSYNCD_CONF$role";
}


