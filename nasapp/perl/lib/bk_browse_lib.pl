#!/usr/bin/perl
#########################################################################################################
#   (C) Copyright Promise Technology Inc., 2012 All Rights Reserved                                     #
#  Name: bk_browse_lib.pl                                                                               #
#  Author: Kinix                                                                                        #
#  Date: 2012/10/22                                                                                     #
#  Description: This perl is some sub routines for browsing remote site.                                #
#               GetRemoteModule  <- OctToChr                                                            #
#               GetRemoteShareDiskConnection                                                            #
#               GetShareDiskUsedAvailable                                                               #
#               GetRemoteShareDiskUsedAvailable                                                         #
#########################################################################################################
require "/nasapp/perl/lib/common.pl";      #trim
require "/nasapp/perl/lib/cmd_path.pl";    #$RSYNC_CMD, $SSH_CMD, $TASKSET_CMD
require "/nasapp/perl/lib/fs_lib.pl";      #get_share_disk_info
require "/nasapp/perl/lib/bk_def.pl";      #$BK_SERVER_COMMENT, $BK_RSYNC_CONTIMEOUT, $CPU_CORE_RSYNC_CLIENT, $PL_BKBROWSEUTIL
require "/nasapp/perl/lib/bk_ssh_lib.pl";  #PutSSHPublicKeyToRemote, SSHCmdOpen, SSHCmdClose
require "/nasapp/perl/lib/bk_task_lib.pl"; #RsyncCommandSSHPort, EscapeSpace

######################################
# Get remote rsync modules           #
#   Input:                           #
#           $_[0]: remote site       #
#           $_[1]: via ssh or not    #
#           $_[2]: port              #
#   Output:                          #
#           $_[3]: module list array #
#   Return:                          #
#           0 for success            #
#           1 for fail case          #
######################################
sub GetRemoteModule
{
	my $remoteSite = shift;
	my $sshswitch = shift;
	my $port = shift;
	my $moduleList = shift;
	my $result = 0;

	my $command = "$RSYNC_CMD ";
	if($sshswitch eq "1") {
		$command = $command."-e '$SSH_CMD -o StrictHostKeyChecking=no -o ConnectTimeout=$BK_RSYNC_CONTIMEOUT";
		if($port ne "") {
			$command = $command." -p $port";
		}
		$command = $command."' ";
	}
	else {
		$command = $command."--contimeout=$BK_RSYNC_CONTIMEOUT ";
		if($port ne "") {
			$command = $command."--port=$port ";
		}
	}
	$command = $command."$remoteSite\:\: 2>&1 |";
	$command = "$TASKSET_CMD -c $CPU_CORE_RSYNC_CLIENT ".$command if($CPU_CORE_RSYNC_CLIENT ne "");
	if($sshswitch eq "1") {
		PutSSHPublicKeyToRemote($remoteSite);
	}
	open(my $IN, $command);
	while(<$IN>) {
		if(/(.+)\s+$BK_SERVER_COMMENT/) {
			push(@$moduleList, OctToChr(trim($1)));
		}
		elsif(/rsync error/) {
			$result = 1;
			last;
		}
	}
	close($IN);
	if(0 == $result) {
		@$moduleList = sort{uc($a) cmp uc($b)}(@$moduleList);
	}
	return $result;
}


########################################################
# Transfer oct to chr                                  #
#   Input:                                             #
#           $_[0]: oct form string                     #
#                  Ex:"\#351\#237\#263\#346\#250\#202" #
#                     or "\#134#351"                   #
#   Return:                                            #
#           unicode character string                   #
########################################################
sub OctToChr
{
	my $input = shift;
	$input =~ s/\\#(\d+)/chr(oct($1))/eg;
	return $input;
}


######################################
# Get remote Share Disk connection   #
#   Input:                           #
#           $_[0]: remote site       #
#           $_[1]: Share Disk name   #
#           $_[2]: via ssh or not    #
#           $_[3]: port              #
#   Return:                          #
#           0 for success            #
#           1 for fail case          #
#           5 for connection timeout #
######################################
sub GetRemoteShareDiskConnection
{
	my $remoteSite = shift;
	my $shareDisk = shift;
	my $sshswitch = shift;
	my $port = shift;
	my $result = 0;

	my $command = "$RSYNC_CMD ";
	$command = $command.RsyncCommandSSHPort($sshswitch, $port, $BK_RSYNC_CONTIMEOUT);
	if($sshswitch eq "1") {
		$command = $command.EscapeSpace("\'$remoteSite\:$SSHRSYNC_PREFIX/$shareDisk\'")." -n 2>&1 |";
	}
	else {
		$command = $command."promise\@$remoteSite\:\:$shareDisk -n 2>&1 |";
	}
	$command = "$TASKSET_CMD -c $CPU_CORE_RSYNC_CLIENT ".$command if($CPU_CORE_RSYNC_CLIENT ne "");
	if($sshswitch eq "1") {
		PutSSHPublicKeyToRemote($remoteSite);
	}
	print "Command:$command\n";
	open(my $IN, $command);
	while(<$IN>) {
		print "$_";
		if(/rsync error: timeout waiting for daemon connection/ || /Connection timed out/) {
			$result = 5;
			last;
		}
		if(/rsync error/) {
			$result = 1;
			last;
		}
	}
	close($IN);
	return $result;
}


################################################
# Get local Share Disk used and available size #
#   Input:                                     #
#           $_[0]: Share Disk name             #
#   Output:                                    #
#           $_[1]: used size in MB             #
#           $_[2]: available size in MB        #
################################################
sub GetShareDiskUsedAvailable
{
	my $shareDisk = shift;
	my $used = shift;
	my $available = shift;

	$$used = -1 if($used ne "");
	$$available = -1 if($available ne "");

	my @shareDiskInfo = get_share_disk_info();
	for(my $i=0; $i<scalar(@shareDiskInfo); $i++) {
		if(${@shareDiskInfo[$i]}{'sdname'} eq $shareDisk) {
			$$used = ${@shareDiskInfo[$i]}{'used'};
			$$available = ${@shareDiskInfo[$i]}{'available'};
			last;
		}
	}
}


#################################################
# Get remote Share Disk used and available size #
#   Input:                                      #
#           $_[0]: Remote IP                    #
#           $_[1]: Share Disk name              #
#   Output:                                     #
#           $_[2]: used size in MB              #
#           $_[3]: available size in MB         #
#################################################
sub GetRemoteShareDiskUsedAvailable
{
	my $remote = shift;
	my $shareDisk = shift;
	my $used = shift;
	my $available = shift;

	$$used = -1 if($used ne "");
	$$available = -1 if($available ne "");

	my $IN;
	SSHCmdOpen(\$IN, $remote, "$PL_BKBROWSEUTIL GetShareDiskUsedAvailable \"$shareDisk\"");
	while(<$IN>) {
		if($used ne "" && /Used\s+(\d+)/) {
			$$used = $1;
		}
		elsif($available ne "" && /Available\s+(\d+)/) {
			$$available = $1;
		}
	}
	SSHCmdClose(\$IN);
}

