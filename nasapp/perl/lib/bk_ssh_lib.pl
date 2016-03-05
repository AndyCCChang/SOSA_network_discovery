#!/usr/bin/perl
#########################################################################################################
#   (C) Copyright Promise Technology Inc., 2012 All Rights Reserved                                     #
#  Name: bk_ssh_lib.pl                                                                                  #
#  Author: Kinix                                                                                        #
#  Date: 2012/10/22                                                                                     #
#  Description: This perl is some sub routines for ssh back door.                                       #
#               PutSSHPublicKeyToRemote                                                                 #
#               RemoveSSHPublicKeyFromRemote                                                            #
#               SSHSystem                    <- RemoteNodeIsActive                                      #
#               SSHCmdOpen                   <- RemoteNodeIsActive                                      #
#               SSHCmdClose                                                                             #
#               CombinSSHCommand                                                                        #
#               SyncFileToRemote             <- WriteTimeStamp, RemoteNodeIsActive                      #
#               SyncNasData                  <- RemoteNodeIsActive                                      #
#               GetConnectionLocalIP                                                                    #
#########################################################################################################
require "/nasapp/perl/lib/cmd_path.pl";    #$SSHKEYGEN_CMD, $CP_CMD, $TASKSET_CMD, $RM_CMD, $SSH_CMD, $KILL_CMD, $NETSTAT_CMD, $I2ARYTOOL_CMD, $GETHISCTLRINFO_CMD, $UNAME_CMD
require "/nasapp/perl/lib/conf_path.pl";   #$RSYNC_PASSWD, $ETH1IP_REMOTE, $TIMESTAMP_FILE, $NASDATA_PATH
require "/nasapp/perl/lib/bk_def.pl";      #$BDRYC_CMD, $BDRYC_PORT, $BK_RSYNC_CONTIMEOUT, $CPU_CORE_RSYNC_CLIENT, $BDSHD_PORT

######################################
# Sent SSH public key to remote site #
#   Input:                           #
#           $_[0]: remote site       #
#   Return:                          #
#           0 success, 1 failed      #
######################################
sub PutSSHPublicKeyToRemote
{
	my $remoteSite = shift;
	my $result = 0;

	if($remoteSite eq "") {
		return 1;
	}

	if(!(-f "/root/.ssh/id_rsa") || !(-f "/root/.ssh/id_rsa.pub")) {
		unlink("/root/.ssh/id_rsa");
		system("$SSHKEYGEN_CMD -f /root/.ssh/id_rsa -P '' -N '' >/dev/null 2>/dev/null");
	}
	unlink("/tmp/authorized_keys");
	system("$CP_CMD -pf /root/.ssh/id_rsa.pub /tmp/authorized_keys");

	my $command = "$BDRYC_CMD -a --port=$BDRYC_PORT --contimeout=$BK_RSYNC_CONTIMEOUT /tmp/authorized_keys promise\@$remoteSite\:\:KEY/ --password-file=$RSYNC_PASSWD 2>/tmp/rsync.err";
	$command = "$TASKSET_CMD -c $CPU_CORE_RSYNC_CLIENT ".$command if($CPU_CORE_RSYNC_CLIENT ne "");
	system($command);
	open(my $IN, "/tmp/rsync.err");
	while(<$IN>) {
		if(/rsync error/) {
			$result = 1;
			last;
		}
	}
	close($IN);
	unlink("/tmp/rsync.err");
	unlink("/tmp/authorized_keys");
	return $result;
}


##########################################
# Remove SSH public key from remote site #
#   Input:                               #
#           $_[0]: remote site           #
#   Return:                              #
#           Error messages               #
##########################################
sub RemoveSSHPublicKeyFromRemote
{
	my $remoteSite = shift;
	return SSHSystem($remoteSite, "$RM_CMD -f /root/.ssh/authorized_keys &");
}


######################################
# Run system at remote site via SSH  #
#   Input:                           #
#           $_[0]: remote site       #
#           $_[1]: command           #
#   Return:                          #
#           system return code       #
#           -1 for connection failed #
######################################
sub SSHSystem
{
	my $remoteSite = shift;
	my $command = shift;

	if($remoteSite eq "" && -f $ETH1IP_REMOTE && RemoteNodeIsActive()) {
		open(my $IN, $ETH1IP_REMOTE);
		$remoteSite = <$IN>;
		chomp($remoteSite);
		close($IN);
	}
	my $result = PutSSHPublicKeyToRemote($remoteSite);
	if(0 == $result) {
		$result = system(CombinSSHCommand($remoteSite, $command));
	}
	return $result;
}


#######################################
# Open command at remote site via SSH #
#   Input:                            #
#           $_[0]: handler            #
#           $_[1]: remote site        #
#           $_[2]: command            #
#   Return:                           #
#           open return code          #
#           -1 for connection failed  #
#######################################
sub SSHCmdOpen
{
	my $handler = shift;
	my $remoteSite = shift;
	my $command = shift;

	if($remoteSite eq "" && -f $ETH1IP_REMOTE && RemoteNodeIsActive()) {
		open(my $IN, $ETH1IP_REMOTE);
		$remoteSite = <$IN>;
		chomp($remoteSite);
		close($IN);
	}
	my $result = PutSSHPublicKeyToRemote($remoteSite);
	if(0 == $result) {
		$result = open($$handler, CombinSSHCommand($remoteSite, $command)." |");
	}
	return $result;
}


########################################
# Close command at remote site via SSH #
#   Input:                             #
#           $_[0]: handler             #
########################################
sub SSHCmdClose
{
	my $hanlder = shift;
	close($$handler);
}


##########################################
# Combine SSH remote back door command   #
#   Input:                               #
#           $_[0]: remote site           #
#           $_[1]: command               #
#   Return:                              #
#           SSH remote back door command #
##########################################
sub CombinSSHCommand
{
	my $remoteSite = shift;
	my $command = shift;
	my $result = "";

	if($remoteSite ne "") {
		$result = "$SSH_CMD -p $BDSHD_PORT -o StrictHostKeyChecking=no -o ConnectTimeout=$BK_RSYNC_CONTIMEOUT root@".$remoteSite;
		if($command ne "") {
			$result = $result." '$command'";
		}
	}
	return $result;
}


##################################################
# Copy file or folder to remote Site             #
#   Input:                                       #
#           $_[0]: remote site                   #
#           $_[1]: file path                     #
#           $_[2]: flag for no writing timestamp #
#   Return:                                      #
#           0 for success                        #
#           1 for failed                         #
##################################################
sub SyncFileToRemote
{
	my $remoteSite = shift;
	my $filePath = shift;
	my $noWTS = shift;
	my $writets = 0;
	my $result = 0;

	if($filePath eq "") {
		return 1;
	}

	if($remoteSite eq "" && $noWTS ne "1") {
		WriteTimeStamp();
		$writets = 1;
	}

	if($remoteSite eq "" && -f $ETH1IP_REMOTE && RemoteNodeIsActive()) {
		open(my $IN, $ETH1IP_REMOTE);
		$remoteSite = <$IN>;
		chomp($remoteSite);
		close($IN);
	}
	my $result = PutSSHPublicKeyToRemote($remoteSite);
	if(0 == $result) {
		my $command = "$BDRYC_CMD -aRKe";
		$command = $command." '$SSH_CMD -p $BDSHD_PORT -o StrictHostKeyChecking=no -o ConnectTimeout=$BK_RSYNC_CONTIMEOUT' \"$filePath";
		$command = $command."/" if(-d $filePath);
		$command = $command."\" \'$remoteSite\:\/'";
		$command = $command." --delete" if(-d $filePath);
		$command = "$TASKSET_CMD -c $CPU_CORE_RSYNC_CLIENT ".$command if($CPU_CORE_RSYNC_CLIENT ne "");
		$result = system($command);
	}
	#sync timestamp
	if(0 == $result && 1 == $writets) {
		my $command = "$BDRYC_CMD -aRKe";
		$command = $command." '$SSH_CMD -p $BDSHD_PORT -o StrictHostKeyChecking=no -o ConnectTimeout=$BK_RSYNC_CONTIMEOUT' \"$TIMESTAMP_FILE\" \'$remoteSite\:\/'";
		$command = "$TASKSET_CMD -c $CPU_CORE_RSYNC_CLIENT ".$command if($CPU_CORE_RSYNC_CLIENT ne "");
		system($command);
	}
	return $result;
}


##################################
# Sync nasdata between two nodes #
#   Return:                      #
#           0 for success        #
#           1 for failed         #
##################################
sub SyncNasData
{
	my $remoteSite = "";
	if(-f $ETH1IP_REMOTE && RemoteNodeIsActive()) {
		open(my $IN, $ETH1IP_REMOTE);
		$remoteSite = <$IN>;
		chomp($remoteSite);
		close($IN);
	}
	my $result = PutSSHPublicKeyToRemote($remoteSite);
	if(0 == $result) {
		my $command = "$BDRYC_CMD -aRKe";
		$command = $command." '$SSH_CMD -p $BDSHD_PORT -o StrictHostKeyChecking=no -o ConnectTimeout=$BK_RSYNC_CONTIMEOUT'";
		$command = $command." \"$NASDATA_PATH/\" \'$remoteSite\:\/'";
		$command = $command." --delete";
		$command = "$TASKSET_CMD -c $CPU_CORE_RSYNC_CLIENT ".$command if($CPU_CORE_RSYNC_CLIENT ne "");
		$result = system($command);
	}
	return $result;
}


############################################
# Get local IP of the connection to remote #
#   Input:                                 #
#           $_[0]: remote site             #
#   Return:                                #
#           local IP address               #
############################################
sub GetConnectionLocalIP
{
	my $remoteSite = shift;
	my $localIP = "";

	my $SSH;
	my $pid = SSHCmdOpen(\$SSH, $remoteSite, "");
	open(my $NETSTAT, "$NETSTAT_CMD -atnp |");
	while(<$NETSTAT>) {
		if(/tcp\s+\d+\s+\d+\s+(.+)\:\d+\s+$remoteSite\:\d+\s+ESTABLISHED\s+$pid\//) {
			$localIP = $1;
			last;
		}
	}
	close($NETSTAT);
	system("$KILL_CMD -9 $pid") if($pid ne "");
	SSHCmdClose(\$SSH);
	return $localIP;
}


######################################
# Check remote node is active or not #
#   Return:                          #
#           0: not active            #
#           1: active                #
######################################
sub RemoteNodeIsActive
{
	my $result = 1;
	open(my $CMD, "$I2ARYTOOL_CMD ctrl |");
	while(<$CMD>) {
		if(/Not Present/) {
			$result = 0;
			last;
		}
	}
	close($CMD);
	return $result;
}


############################
# Write nasdata time stamp #
############################
sub WriteTimeStamp
{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdest) = localtime(time);
	$year += 1900;
	$mon += 1;
	open(my $OUT, "> $TIMESTAMP_FILE");
	print $OUT sprintf("%04d%02d%02d%02d%02d%02d",$year,$mon,$mday,$hour,$min,$sec);
	close($OUT);
}



