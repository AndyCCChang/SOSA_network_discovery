#!/usr/bin/perl
#########################################################################################################
#   (C) Copyright Promise Technology Inc., 2012 All Rights Reserved                                     #
#  Name: bk_task_lib.pl                                                                                 #
#  Author: Kinix                                                                                        #
#  Date: 2012/10/22                                                                                     #
#  Description: This perl is some sub routines for all rsync backup tasks.                              #
#               GetTaskNumber                                                                           #
#               CheckSchedule   <- CheckTimeFormat                                                      #
#               SetTaskSchedule <- PrintCrontab                                                         #
#               MakeConfigFile                                                                          #
#               ReadConfigFile                                                                          #
#               BackupTaskRenameShareDisk <- ReadConfigFile                                             #
#               RemoveTask      <- SetTaskSchedule, KillPidByFile                                       #
#               CheckPidByFile                                                                          #
#               GetProgress                                                                             #
#               SetLastResult                                                                           #
#               GetLastResult                                                                           #
#               RsyncCommandSSHPort                                                                     #
#               EscapeSpace                                                                             #
#               EscapeWildcard                                                                          #
#               AntiEscapeWildcard                                                                      #
#########################################################################################################
require "/nasapp/perl/lib/common.pl";      #gen_random_filename
require "/nasapp/perl/lib/cmd_path.pl";    #$CP_CMD, $MV_CMD, $KILL_CMD, $PS_CMD
require "/nasapp/perl/lib/conf_path.pl";   #$CONF_CRONTAB, $RSYNC_PASSWD
require "/nasapp/perl/lib/bk_def.pl";

###########################################
# Get task number                         #
#   Return the task number of backup mode #
#   Input:                                #
#           $_[0]: backup mode            #
#   Return:                               #
#           task number                   #
###########################################
sub GetTaskNumber
{
	my $bkMode = shift;   #backup mode
	my $result = 0;
	my $dirName = "";
	opendir(my $DIR, "$BK_TASK_PREFIX/$bkMode");
	while($dirName = readdir($DIR)) {
		if($dirName eq "." || $dirName eq ".."
				|| (!-f "$BK_TASK_PREFIX/$bkMode/$dirName/$BK_TASK_CONFFILE")) {
			next;
		}
		$result++;
	}
	closedir($DIR);
	return $result;
}


######################################################
# Check Schedule                                     #
#   If information isn't complete, make a random one #
#   Input:                                           #
#           $_[0]: schedule string for checking      #
#   Output:                                          #
#           $_[0]: schedule string after checking    #
#   Return:                                          #
#           -1 for illegal case                      #
######################################################
sub CheckSchedule
{
	my $schedule = shift;
	my $scheduleType = "";
	my $time1 = "";
	my $time2 = "";
	my $hour = "";
	my $minute = "";

	if($$schedule =~ /(\d),{0,1}([^,]*),{0,1}(.*)/) {
		$scheduleType = $1;
		$time1 = $2;
		$time2 = $3;
	}

	#Disable
	if(0 == $scheduleType) {
		$$schedule = "0";
	}
	#Minute(s)
	elsif(1 == $scheduleType) {
		if($time1 > 20)    { $time1 = 30; }
		elsif($time1 > 15) { $time1 = 20; } 
		elsif($time1 > 10) { $time1 = 15; }
		elsif($time1 > 5)  { $time1 = 10; }
		elsif($time1 > 1)  { $time1 = 5; }
		elsif($time1 > 0)  { $time1 = 1; } 
		else { $time1 = 30; }
		$$schedule = "1,$time1";
	}
	#Hour(s)
	elsif(2 == $scheduleType) {
		if($time1 > 8)    { $time1 = 12; }
		elsif($time1 > 6) { $time1 = 8; }
		elsif($time1 > 4) { $time1 = 6; }
		elsif($time1 > 3) { $time1 = 4; }
		elsif($time1 > 2) { $time1 = 3; }
		elsif($time1 > 1) { $time1 = 2; }
		elsif($time1 > 0) { $time1 = 1; }
		else { $time1 = 12; }

		if($time2 > 0 && $time2 <= 59 || $time2 eq "0") {
			$time2 += 0; #make sure it's number
		}
		else {
			$time2 = int(rand(60));
		}
		$$schedule = "2,$time1,$time2";
	}
	#Daily
	elsif(3 == $scheduleType) {
		CheckTimeFormat($time1, \$hour, \$minute);
		$$schedule = "3,$hour:$minute";
	}
	#Weekly
	elsif(4 == $scheduleType) {
		if($time1 > 0 && $time1 <= 6 || $time1 eq "0") {
			$time1 += 0; #make sure it's number
		}
		else {
			$time1 = int(rand(7));
		}
		CheckTimeFormat($time2, \$hour, \$minute);
		$$schedule = "4,$time1,$hour:$minute";
	}
	#Monthly
	elsif(5 == $scheduleType) {
		if($time1 >= 1 && $time1 <= 28) {
			$time1 += 0; #make sure it's number
		}
		else {
			$time1 = int(rand(28))+1;
		}
		CheckTimeFormat($time2, \$hour, \$minute);
		$$schedule = "5,$time1,$hour:$minute";
	}
	else {
		print "Error: Wrong schedule format!\n";
		return -1;
	}
}


###############################################
# Check time format                           #
#   If format is incorrect, make a random one #
#   Input:                                    #
#           $_[0]: time string for checking   #
#   Output:                                   #
#           $_[1]: variable for hour          #
#           $_[2]: variable for minute        #
###############################################
sub CheckTimeFormat
{
	my $time = shift;
	my $hour = shift;
	my $minute = shift;

	if($time =~ /(\d+):(\d+)/) {
		$$hour = $1;
		$$minute = $2;
		if($$hour > 23 || $$hour < 0) {
			$$hour = int(rand(24));
		}
		else {
			$$hour += 0; #make sure it's number
		}
		if($$minute > 59 || $$minute < 0) {
			$$minute = int(rand(60));
		}
		else {
			$$minute += 0; #make sure it's number
		}
	}
	else {
		$$hour = int(rand(24));
		$$minute = int(rand(60));
	}
}


############################################################
# Set task schedule                                        #
#   Set task schedule in specific operation with task name #
#   Input:                                                 #
#           $_[0]: operation ("update" or "remove")        #
#           $_[1]: backup mode                             #
#           $_[2]: task name                               #
#   Return:                                                #
#           0:Success                                      #
#           1:Fail                                         #
#           2:Wrong argument                               #
############################################################
sub SetTaskSchedule
{
	my $option = shift;   #option (update or remove)
	my $bkMode = shift;   #backup mode
	my $taskName = shift; #task name Ex:dailybackup

	my $taskFile = "$BK_TASK_PREFIX/$bkMode/$taskName/$BK_TASK_CONFFILE";

	my $scheduleType = "";
	my $scheduleTime1 = "";
	my $scheduleTime2 = "";

	if($option ne "update" && $option ne "remove") {
		return 2;
	}

	if(! -f $taskFile) {
		print "Error:$bkMode mode task \"$taskName\" configure file doesn't exist!\n";
		return 1;
	}

	my $IN;
	my $inTaskFile = gen_random_filename($taskFile);
	system("$CP_CMD -af \"$taskFile\" \"$inTaskFile\"");
	open($IN, "< $inTaskFile");
	while(<$IN>) {
		if(/Schedule:(\d),([^,\ \t\f\r\n]+),{0,1}(.*)/) {
			$scheduleType = $1;
			$scheduleTime1 = $2;
			$scheduleTime2 = $3;
		}
	}
	close($IN);
	unlink($inTaskFile);

	### Edit crontab file ###
	my $OUT;
	my $match = 0;
	my $command = "$PL_BKRSYNCTASK \"$bkMode\" \"$taskName\"";
	my $inCrontab = gen_random_filename($CONF_CRONTAB);
	my $outCrontab = gen_random_filename($CONF_CRONTAB);
	system("$CP_CMD -af \"$CONF_CRONTAB\" \"$inCrontab\"");
	open($OUT, "> $outCrontab");
	open($IN, "< $inCrontab");
	while(<$IN>) {
		if(/$PL_BKRSYNCTASK\s+\"$bkMode\"\s+\"$taskName\"/) {
			if($option eq "remove") {
				next;
			}
			$match = 1;
			PrintCrontab($OUT, $scheduleType, $scheduleTime1, $scheduleTime2, $command);
		}
		else {
			print $OUT "$_";
		}
	}
	if(0 == $match && $option eq "update") {
		PrintCrontab($OUT, $scheduleType, $scheduleTime1, $scheduleTime2, $command);
	}
	close($OUT);
	close($IN);
	unlink($inCrontab);
	system("$MV_CMD -f \"$outCrontab\" \"$CONF_CRONTAB\"");
	return 0;
}


###############################################################
# Print crontab                                               #
#   Print schedule settings in crontab format to file handler #
#   Format: m h dom mon dow user  command                     #
#   Input:                                                    #
#          $_[0]: file handler for print out                  #
#          $_[1]: schedule type                               #
#          $_[2]: schedule time1                              #
#          $_[3]: schedule time2                              #
#          $_[4]: command                                     #
###############################################################
sub PrintCrontab
{
	my $FH = shift;
	my $scheduleType = shift;
	my $scheduleTime1 = shift;
	my $scheduleTime2 = shift;
	my $command = shift;

	### Now ###
	if(0 == $scheduleType) {
		print $FH "#* * * * *\troot\t$command\n";	#run now doesn't need schedule
	}
	### Minute ###
	elsif(1 == $scheduleType) {
		print $FH "*/$scheduleTime1 * * * *\troot\t$command\n";
	}
	### Hour ###
	elsif(2 == $scheduleType) {
		print $FH "$scheduleTime2 */$scheduleTime1 * * *\troot\t$command\n";
	}
	### Daily ###
	elsif(3 == $scheduleType) {
		my $hour, $minute;
		if($scheduleTime1 =~ /(\d+):(\d+)/) {
			$hour = $1;
			$minute = $2;
			print $FH "$minute $hour * * *\troot\t$command\n";
		}
	}
	### Weekly ###
	elsif(4 == $scheduleType) {
		my $hour, $minure;
		if($scheduleTime2 =~ /(\d+):(\d+)/) {
			$hour = $1;
			$minute = $2;
			print $FH "$minute $hour * * $scheduleTime1\troot\t$command\n";
		}
	}
	### Monthly ###
	elsif(5 == $scheduleType) {
		my $hour, $minute;
		if($scheduleTime2 =~ /(\d+):(\d+)/) {
			$hour = $1;
			$minute = $2;
			print $FH "$minute $hour $scheduleTime1 * *\troot\t$command\n";
		}
	}
}


#######################################
# Make task configure file            #
#   Input:                            #
#           $_[0]: backup mode        #
#           $_[1]: task name          #
#           $_[2]: source             #
#           $_[3]: target             #
#           $_[4]: policy             #
#           $_[5]: ssh                #
#           $_[6]: port               #
#           $_[7]: schedule           #
#           $_[8]: connection timeout #
#           $_[9]: retry time         #
#           $_[10]: bandwidth in KBPS #
#######################################
sub MakeConfigFile
{
	my $bkMode = shift;
	my $taskName = shift;
	my $source = shift;
	my $target = shift;
	my $policy = shift;
	my $sshswitch = shift;
	my $port = shift;
	my $schedule = shift;
	my $contimeout = shift;
	my $retry = shift;
	my $bwlimit = shift;

	open(my $FILE, "> $BK_TASK_PREFIX/$bkMode/$taskName/$BK_TASK_CONFFILE");
	print $FILE "Mode:$bkMode\n";
	print $FILE "Name:$taskName\n";
	print $FILE "Source:$source\n";
	print $FILE "Target:$target\n";
	print $FILE "Policy:$policy\n";
	print $FILE "SSH:$sshswitch\n";
	print $FILE "Port:$port\n";
	print $FILE "Schedule:$schedule\n";
	print $FILE "ConTimeout:$contimeout\n";
	print $FILE "Retry:$retry\n";
	print $FILE "BWLimit:$bwlimit\n";
	close($FILE);
}


########################################
# Read task configure file             #
#   Input:                             #
#           $_[0]: configure file path #
#   Output:                            #
#           $_[1]: backup mode         #
#           $_[2]: task name           #
#           $_[3]: source              #
#           $_[4]: target              #
#           $_[5]: policy              #
#           $_[6]: ssh                 #
#           $_[7]: port                #
#           $_[8]: schedule            #
#           $_[9]: connection timeout  #
#           $_[10]: retry time         #
#           $_[11]: bandwidth in KBPS  #
#   Return:                            #
#           0 for success              #
#           1 for fail case            #
########################################
sub ReadConfigFile
{
	my $filePath = shift;
	my $bkMode = shift;
	my $taskName = shift;
	my $source = shift;
	my $target = shift;
	my $policy = shift;
	my $sshswitch = shift;
	my $port = shift;
	my $schedule = shift;
	my $contimeout = shift;
	my $retry = shift;
	my $bwlimit = shift;

	if(!-f $filePath) {
		print "Error: Cant read configure file \"$filePath\"!\n";
		return 1;
	}

	$$bkMode = "" if($bkMode ne "");
	$$taskName = "" if($taskName ne "");
	$$source = "" if($source ne "");
	$$target = "" if($target ne "");
	$$policy = "" if($policy ne "");
	$$sshswitch = "" if($sshswitch ne "");
	$$port = "" if($port ne "");
	$$schedule = "" if($schedule ne "");
	$$contimeout = "" if($contimeout ne "");
	$$retry = "" if($retry ne "");
	$$bwlimit = "" if($bwlimit ne "");
	my $inFilePath = gen_random_filename($filePath);
	system("$CP_CMD -af \"$filePath\" \"$inFilePath\"");
	open(my $IN, "< $inFilePath");
	while(<$IN>) {
		if($bkMode ne "" && /Mode:(.*)/) {
			$$bkMode = $1;
		}
		elsif($taskName ne "" && /Name:(.*)/) {
			$$taskName = $1;
		}
		elsif($source ne "" && /Source:(.*)/) {
			$$source = $1;
		}
		elsif($target ne "" && /Target:(.*)/) {
			$$target = $1;
		}
		elsif($policy ne "" && /Policy:(.*)/) {
			$$policy = $1;
		}
		elsif($sshswitch ne "" && /SSH:(.*)/) {
			$$sshswitch = $1;
		}
		elsif($port ne "" && /Port:(.*)/) {
			$$port = $1;
		}
		elsif($schedule ne "" && /Schedule:(.*)/) {
			$$schedule = $1;
		}
		elsif($contimeout ne "" && /ConTimeout:(.*)/) {
			$$contimeout = $1;
		}
		elsif($retry ne "" && /Retry:(.*)/) {
			$$retry = $1;
		}
		elsif($bwlimit ne "" && /BWLimit:(.*)/) {
			$$bwlimit = $1;
		}
	}
	close($IN);
	unlink($inFilePath);
	return 0;
}


#################################################
# Modify all backup tasks for Share Disk rename #
#   Input:                                      #
#           $_[0]: Old Share Disk name          #
#           $_[1]: New Share Disk name          #
#################################################
sub BackupTaskRenameShareDisk
{
	my $oldName = shift;
	my $newName = shift;
	my $bkMode, $taskName, $source, $target, $policy, $sshswitch, $port, $schedule;
	my $contimeout, $retry, $bwlimit;
	my $DIR;

	###Replication Tasks###
	opendir($DIR, $BK_REPLICATION_PREFIX);
	while($dirName = readdir($DIR)) {
		if($dirName eq "." || $dirName eq ".."
				|| (!-f "$BK_REPLICATION_PREFIX/$dirName/$BK_TASK_CONFFILE")) {
			next;
		}
		ReadConfigFile("$BK_REPLICATION_PREFIX/$dirName/$BK_TASK_CONFFILE",
				\$bkMode, \$taskName, \$source, \$target, \$policy, \$sshswitch, \$port, \$schedule,
				\$contimeout, \$retry, \$bwlimit);
		my $modified = 0;
		my @shareDisks = split(/,/, $source);
		$source = "";
		for(my $i=0; $i<scalar(@shareDisks); $i++) {
			$source = $source."," if($i > 0);
			if($shareDisks[$i] eq $oldName) {
				$shareDisks[$i] = $newName;
				$modified = 1;
			}
			$source = $source.$shareDisks[$i];
		}
		if(1 == $modified) {
			MakeConfigFile($bkMode, $taskName, $source, $target, $policy, $sshswitch, $port, $schedule,
				$contimeout, $retry, $bwlimit);
		}
	}
	closedir($DIR);

	###Clone Tasks###
	opendir($DIR, $BK_CLONE_PREFIX);
	while($dirName = readdir($DIR)) {
		if($dirName eq "." || $dirName eq ".."
				|| (!-f "$BK_CLONE_PREFIX/$dirName/$BK_TASK_CONFFILE")) {
			next;
		}
		ReadConfigFile("$BK_CLONE_PREFIX/$dirName/$BK_TASK_CONFFILE",
				\$bkMode, \$taskName, \$source, \$target, \$policy, \$sshswitch, \$port, \$schedule,
				\$contimeout, \$retry, \$bwlimit);
		my $modified = 0;
		if($source eq $oldName) {
			$source = $newName;
			$modified = 1;
		}
		if($target eq $oldName) {
			$target = $newName;
			$modified = 1;
			system("$MV_CMD -f \"$BK_CLONE_PREFIX/$oldName\" \"$BK_CLONE_PREFIX/$newName\"");
		}
		if(1 == $modified) {
			MakeConfigFile($bkMode, $target, $source, $target, $policy, $sshswitch, $port, $schedule,
				$contimeout, $retry, $bwlimit);
		}
	}
	closedir($DIR);

	###Backup Tasks###
	opendir($DIR, $BK_BACKUP_PREFIX);
	while($dirName = readdir($DIR)) {
		if($dirName eq "." || $dirName eq ".."
				|| (!-f "$BK_BACKUP_PREFIX/$dirName/$BK_TASK_CONFFILE")) {
			next;
		}
		ReadConfigFile("$BK_BACKUP_PREFIX/$dirName/$BK_TASK_CONFFILE",
				\$bkMode, \$taskName, \$source, \$target, \$policy, \$sshswitch, \$port, \$schedule,
				\$contimeout, \$retry, \$bwlimit);
		my $modified = 0;
		if($target =~ /(.*)\x4\:\x4(.+)/) {
			if($1 eq "" && $2 eq $oldName) {
				$target = "\x4:\x4".$newName;
				$modified = 1;
			}
		}
		if($source =~ /([^:]+):(.*)/) {
			if($1 eq $oldName) {
				$source = $newName.":".$2;
				$modified = 1;
			}
		}
		if(1 == $modified) {
			MakeConfigFile($bkMode, $taskName, $source, $target, $policy, $sshswitch, $port, $schedule,
				$contimeout, $retry, $bwlimit);
		}
	}
	closedir($DIR);
	SyncFileToRemote("", $BK_TASK_PREFIX);
}


############################################
# Remove task by backup mode and task name #
#   Input:                                 #
#           $_[0]: backup mode             #
#           $_[1]: task name               #
#   Return:                                #
#           0:Success                      #
#           1:Fail                         #
#           2:Wrong argument               #
############################################
sub RemoveTask
{
	my $bkMode = shift;    #backup mode
	my $taskName = shift;  #task name Ex:dailybackup
	my $result;

	return 2 if($bkMode eq "" || $taskName eq "");

	$result = SetTaskSchedule("remove", $bkMode, $taskName);
	return $result if($result != 0);

	my $pid = KillPidByFile("$BK_TASK_PREFIX/$bkMode/$taskName/$BK_TASK_PIDFILE");
	if($pid ne "") {
		print "Error: Kill running task $pid failed!\n";
	}
	system("$RM_CMD -rf \"$BK_TASK_PREFIX/$bkMode/$taskName\"");
	return 0;
}


#######################################
# Kill running task by input pid file #
#   Input:                            #
#           $_[0]: pid file           #
#   Return:                           #
#           empty string for success  #
#           pid for failed            #
#######################################
sub KillPidByFile
{
	my $pidFile = shift;
	if(-f $pidFile) {
		open(my $FILE, "< $pidFile");
		my $pid = <$FILE>;
		chomp $pid;
		close($FILE);
		if(system("$KILL_CMD $pid") != 0) {
			return $pid;
		}
	}
	return "";
}


##################################################
# Check task is running or not by input pid file #
#   Input:                                       #
#           $_[0]: pid file                      #
#   Return:                                      #
#           0: pid task doesn't exist            #
#           1: pid task is running               #
##################################################
sub CheckPidByFile
{
	my $pidFile = shift;
	my $result = 0;
	if(-f $pidFile) {
		open(my $FILE, "< $pidFile");
		my $pid = <$FILE>;
		my $exeTime = <$FILE>;
		chomp $pid;
		chomp $exeTime;
		close($FILE);
		if($pid eq "") {
			return 1;
		}
		open(my $IN, "$PS_CMD -o pid |");
		while(<$IN>) {
			if(/(\d+)/ && $1 eq $pid) {
				$result = 1;
				last;
			}
		}
		close($IN);
		#porcess died unusual
		if(0 == $result) {
			my $resultDir = $pidFile;
			$resultDir =~ /(.+)\/$BK_TASK_PIDFILE$/ and $resultDir = $1;
			SetLastResult("$resultDir/$BK_TASK_RESULT", "Unusual Leave", $exeTime, "1") if(-d $resultDir);
			unlink($pidFile);
		}
	}
	return $result;
}


###########################################
# Parse rsync progress from progress file #
#   Input:                                #
#           $_[0]: progress file path     #
#   Output:                               #
#           $_[1]: description            #
#           $_[2]: progress percentagee   #
#           $_[3]: transfer speed         #
#           $_[4]: left time              #
#           $_[5]: file percentage        #
#   Return:                               #
#           0 for success                 #
#           1 for fail case               #
###########################################
sub GetProgress
{
	my $filePath = shift;
	my $state = shift;
	my $progress = shift;
	my $speed = shift;
	my $leftTime = shift;
	my $filePercent = shift;

	if(!-f $filePath) {
		print "Error: Cant read file \"$filePath\"!\n";
		return 1;
	}

	my $STATE;
	open(my $IN, "< $filePath");
	while(<$IN>) {
		if(/State\:(.*)/) {
			$$state = $1 if($state ne "");
			$STATE = $1;
		}
		elsif(/percentage\:(.*)\s+speed\:(.*)\s+leftTime\:(.*)/) {
			$$filePercent = $1 if($filePercent ne "");
			$$speed = $2 if($speed ne "");
			$$leftTime = $3 if($leftTime ne "");
		}
#		elsif(/(\d+)\/(\d+)/) {
#			$$progress = int((100*$1)/$2) if($progress ne "");
#		}
		elsif(/total\:(\d+)/ && $progress ne "") {
			$$progress = $1 if($1 > $$progress);
		}
	}
	close($IN);
	if($STATE =~ /total\s+size\s+is\s+\d+\s+speedup\s+is/) {
			$$progress = 100 if($progress ne "");
	}

	return 0;
}


#####################################
# Set last result                   #
#   Input:                          #
#           $_[0]: result file path #
#           $_[1]: mode             #
#           $_[2]: time stamp       #
#           $_[3]: result           #
#####################################
sub SetLastResult
{
	my $filePath = shift;
	my $bkMode = shift;
	my $timestamp = shift;
	my $lastResult = shift;

	open(my $FILE, "> $filePath");
	print $FILE "MODE:$bkMode\n";
	print $FILE "TIME:$timestamp\n";
	print $FILE "RESULT:$lastResult\n";
	close($FILE);
}


#####################################
# Get last result                   #
#   Input:                          #
#           $_[0]: result file path #
#   Output:                         #
#           $_[1]: mode             #
#           $_[2]: time stamp       #
#           $_[3]: result           #
#   Return:                         #
#           0 for success           #
#           1 for fail case         #
#####################################
sub GetLastResult
{
	my $filePath = shift;
	my $bkMode = shift;
	my $timestamp = shift;
	my $lastResult = shift;

	if(!-f $filePath) {
		print "Error: Cant read file \"$filePath\"!\n";
		return 1;
	}

	open(my $IN, "< $filePath");
	while(<$IN>) {
		if(/MODE:(.*)/) {
			$$bkMode = $1 if($bkMoe ne "");
		}
		elsif(/TIME\:(.*)/) {
			$$timestamp = $1 if($timestamp ne "");
		}
		elsif(/RESULT\:(.*)/) {
			$$lastResult = $1 if($lastResult ne "");
		}
	}
	close($IN);
	return 0;
}


##############################################################
# Return part of rsync command with ssh and port settings    #
#   Input:                                                   #
#           $_[0]: ssh switch                                #
#           $_[1]: port                                      #
#           $_[2]: connection time out                       #
#   Return:                                                  #
#           Part of rsync command with ssh and port settings #
##############################################################
sub RsyncCommandSSHPort
{
	my $sshswitch = shift;
	my $port = shift;
	my $contimeout = shift;
	my $command = "";

	if($sshswitch eq "1") {
		$command = $command."-e '$SSH_CMD -c arcfour -o StrictHostKeyChecking=no";
		$command = $command." -o ConnectTimeout=$contimeout" if($contimeout ne "");
		$command = $command." -p $port" if($port ne "");
		$command = $command."' ";
	}
	else {
		$command = $command."--contimeout=$contimeout " if($contimeout ne "");
		$command = $command."--port=$port " if($port ne "");
		$command = $command."--password-file=$RSYNC_PASSWD ";
	}
	return $command;
}


#########################################################
# Escape the space by blackslash                        #
#   Input:                                              #
#           $_[0]: path string to handle                #
#   Return:                                             #
#           path string with blackslash to escape space #
#########################################################
sub EscapeSpace
{
	my $path = shift;
	$path =~ s/\s/\\ /g;
	return $path;
}


#########################################################
# Escape the wildcard characters by blackslash          #
#   Input:                                              #
#           $_[0]: path string to handle                #
#   Return:                                             #
#           path string with blackslash to escape space #
#########################################################
sub EscapeWildcard
{
	my $path = shift;
	$path =~ s/\(/\\\(/g;
	$path =~ s/\)/\\\)/g;
	$path =~ s/\[/\\\[/g;
	$path =~ s/\]/\\\]/g;
	$path =~ s/\?/\\\?/g;
	$path =~ s/\*/\\\*/g;
	return $path;
}


############################################
# The anit-function of EscapeWildcard      #
#   Input:                                 #
#           $_[0]: path string to handle   #
#   Return:                                #
#           path string without blackslash #
############################################
sub AntiEscapeWildcard
{
	my $path = shift;
	$path =~ s/\\\(/\(/g;
	$path =~ s/\\\)/\)/g;
	$path =~ s/\\\[/\[/g;
	$path =~ s/\\\]/\]/g;
	$path =~ s/\\\?/\?/g;
	$path =~ s/\\\*/\*/g;
	return $path;
}


