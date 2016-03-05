#!/usr/bin/perl
#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: bk_snap_lib.pl
#  Author: Paul Chang
#  Date: 2012/11/15
#  Description:
#    Tools used in snapshot task.
#########################################################################

require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/bk_snap_def.pl";
require "/nasapp/perl/lib/fs_lib.pl";
require "/nasapp/perl/lib/perm_lib.pl";
require "/nasapp/perl/lib/pro_lib.pl";
require "/nasapp/perl/lib/bk_ssh_lib.pl";    #SyncFileToRemote

##############################################################
#  Change input size to megabyte scale
#  Input:   Disk size(terabytes, gigabytes or megabytes)
#  Output:  Megabyte scaled size
#  Example: calsize_to_M(1.08G); (output=1105.92)
##############################################################
sub calsize_to_M {
	my($size) = @_;
	if ($size =~ /(\d+)[.](\d+)G/ || $size =~ /(\d+)[.](\d+)g/) {
		$size = $1*1024+$2*1024/100;
	}
	elsif ($size =~ /(\d+)[.](\d+)M/ || $size =~ /(\d+)[.](\d+)m/) {
		$size = $1;
	}
	elsif($size =~ /(\d+)[.](\d+)T/ || $size =~ /(\d+)[.](\d+)t/) {
		$size = $1*1024*1024+$2*1024*1024/100;
	}
	elsif($size =~ /(\d+)G/ || $size =~ /(\d+)g/ ) {
		$size = $1*1024;
	}
	elsif($size =~ /(\d+)T/ || $size =~ /(\d+)t/) {
		$size = $1*1024*1024;
	}
	elsif($size =~ /(\d+)M/ || $size =~ /(\d+)m/) {
		$size = $1;
	}
	
	return $size;
}

##########################################################
#  Get Share Disk name of input snapshot
#  Input:   task id(string)
#           timestamp of snapshot(string)
#           vgname(string)
#           originlvname(string)
#  Output:  Snapshot Share Disk name(string)
#  Example: get_snap_sdname(taskid, timestamp, vgname, originlvname)
##########################################################
sub get_snap_sdname {
	my ($taskid, $timestamp, $origin_sdname)=@_;

	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($timestamp);
	my $yyear;
	my $ymon;
	my $present_time;
	my $mountname;
	
	$yyear = $year+1900;
	$ymon = (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mon];
	$mday = (sprintf "%.2d",$mday);
	$hour = (sprintf "%.2d",$hour);
	$min = (sprintf "%.2d",$min);
	$sec = (sprintf "%.2d",$sec);
	$present_time = "$mday$ymon$yyear"."_"."$hour$min$sec";
	$mountname = "$origin_sdname"."_"."$present_time"."_"."$taskid";

	return $mountname;
}

###########################################################
#  Close exported snapshot
#  Input:   snapshot sd name(string)
#  Output:  0=OK, 1=input exported snapshot does not exist, 2=close snapshot failed
#  Example: close_snapshot(snapshot_sdname);
###########################################################
sub close_snapshot {
	my ($snapshot_sdname) = @_;
	chomp($snapshot_sdname);
	
	# check input snapshot name and get information
	my @sdinfo = get_sd_db($snapshot_sdname);
	my $is_exist = @sdinfo;
	if ($is_exist == 0) {
		print "Snapshot \"$snapshot_sdname\" does not export.\n";
		return 1;
	}
	my $vgname = $sdinfo[0]->{"vgname"};
	my $snap_lvname = $sdinfo[0]->{"lvname"};
	my $isEncypted = $sdinfo[0]->{"encrypted"};
	
	my $res = unmount_snapshot($snapshot_sdname, $vgname, $snap_lvname, $isEncypted);
	if ($res != 0) {
		return 2;
	}
			
	# remove from Share Disk table and also default permission as well
	delete_sd_db($snapshot_sdname);
	
	mark_reload_protocol("ALL");
	return 0;
}

###########################################################
#  Get snapshot list
#  Input:   taskid, get all snapshot if taskid=NULL
#  Output:  array of snapshots
#  Example: get_snapshot_list();
###########################################################
sub get_snapshot_list {
	my ($searchtaskid) = @_;
	my @result=();
	my @tempstr;
	my ($lvname, $timestamp, $taskid, $active_flag, $mount_flag, $mount_name);
	
	# get all Share Disk
	my @sdinfo = get_sd_db();
	
	open (my $LVS, "$LVS_CMD --unit g |");
	while (<$LVS>) {
		# lvs  lvsnapshotname    vgname swi-aos-  10.00g      originlv  22.25
		if (/(\S+)\s+(\S+)\s+(\S+)\s+(s.......)\s+/) {
			@tempstr = split(" ", $_);
			$lvname = $tempstr[1];
			if ($lvname =~ /(\S+)TS(\S+)ID(\S+)/) {
				$timestamp = $2;
				$taskid = $3;
			}
			else {
				next;
			}

			$active_flag = substr($tempstr[3], 4, 1);
			if ($active_flag eq "a") {
				$active_flag = "A";
			}
			elsif ($active_flag eq "I") {
				$active_flag = "I";
			}
			else {
				$active_flag = "N";
			}

			$mount_flag = substr($tempstr[3], 5, 1);
			if ($mount_flag eq "o") {
				$mount_flag = 1;
			}
			else {
				$mount_flag = 0;
			}
			
			if ($searchtaskid ne "") {
				if ($searchtaskid eq $taskid) {
					my $sdname = "";
					for $info (@sdinfo) {
						if ($info->{"vgname"} eq $tempstr[2] && $info->{"lvname"} eq $tempstr[5]) {
							$sdname = $info->{"sdname"};
							last;
						}
					}
					$mount_name = get_snap_sdname($taskid, $timestamp, $sdname);
					push @result, {"taskid" => $taskid, "vgname" => $tempstr[2], "original_lvname" => $tempstr[5], "snap_lvname" => $lvname,
								   "snap_sdname" => $mount_name, "timestamp" => $timestamp, "realcap" => $tempstr[4],
								   "usepercent" => $tempstr[6], "status" => $active_flag, "export" => $mount_flag};
					last;
				}
			}
			else {
				my $sdname = "";
				for $info (@sdinfo) {
					if ($info->{"vgname"} eq $tempstr[2] && $info->{"lvname"} eq $tempstr[5]) {
						$sdname = $info->{"sdname"};
						last;
					}
				}
				$mount_name = get_snap_sdname($taskid, $timestamp, $sdname);
				push @result, {"taskid" => $taskid, "vgname" => $tempstr[2], "original_lvname" => $tempstr[5], "snap_lvname" => $lvname,
				               "snap_sdname" => $mount_name, "timestamp" => $timestamp, "realcap" => $tempstr[4],
							   "usepercent" => $tempstr[6], "status" => $active_flag, "export" => $mount_flag};
			}
		}
	}
	close($LVS);
	return @result;
}

###########################################################
#  Get new snapshot task id
#  Input:   -
#  Output:  snapshot task id(3 digit of number)
#  Example: get_new_taskid();
###########################################################
sub get_new_taskid {
	my @taskid;
	my ($origin_snap, $unused);

	if (! -f "$BK_SNAP_CONF") { # config file not exist, create new one
		open (my $OUT, ">$BK_SNAP_CONF");
		print $OUT "CREATED=0\n";
		close ($OUT);
		return "001";
	}
	else {
		@taskid=();
		$origin_snap = gen_random_filename("$BK_SNAP_CONF");
		system("$CP_CMD -f $BK_SNAP_CONF $origin_snap");
		open (my $IN, "<$origin_snap");
		while (<$IN>) {
			if (/\[(\S+)\]/) {
				push @taskid, $1;
			}
		}
		close ($IN);
		unlink("$origin_snap");
		
		@taskid = sort {$a <=> $b}@taskid;
		$unused = 1;
		for $id (@taskid) {
			if ($unused != $id) {
				last;
			}
			else {
				$unused++;
			}
		}
		return sprintf("%03d", $unused);
	}
}

########################################################################################################
#  Add a new snapshot task
#  Input:   vgname        vg name(string)
#           lvname        lv name(string)
#           snapcap       snapshot capacity(string, e.g 20G)
#           autoextend    autoextend snapshot capacity if capacity has been used more than 95%(0 or 1)
#           status        C=Creating, S=Scheduling, A=Active, I=Inactive, D=createD
#  Output:  new task id
#  Example: add_new_snapshot_task(vgname, lvname, 20G, 0);
########################################################################################################
sub add_new_snapshot_task {
	my ($vgname, $lvname, $sdname, $snapcap, $autoextend, $status, $type, $hour, $minute, $day)=@_;
	my ($taskid, $origin_snap, $snaptmp, $created);

	$taskid = get_new_taskid();
	# write task into snap.conf
	$origin_snap = gen_random_filename("$BK_SNAP_CONF");
	$snaptmp = gen_random_filename("$BK_SNAP_CONF");
	system("$CP_CMD -f $BK_SNAP_CONF $origin_snap");

	open(my $OUT, ">$snaptmp");
	open(my $IN, "<$origin_snap");
	while (<$IN>) {
		if (/CREATED\s*=\s*(\d+)/) {
			$created = $1;
			$created += 1;
			print $OUT "CREATED=$created\n";
		}
		else {
			print $OUT "$_";
		}
	}	
	print $OUT "\[$taskid\]\n";
	print $OUT "VGNAME=$vgname\n";
	print $OUT "LVNAME=$lvname\n";
	print $OUT "SDNAME=$sdname\n";
	print $OUT "SNAPCAP=$snapcap\n";
	print $OUT "AUTOEXTEND=$autoextend\n";
	print $OUT "STATUS=$status\n";
	print $OUT "TYPE=$type\n";
	print $OUT "HOUR=$hour\n";
	print $OUT "MINUTE=$minute\n";
	print $OUT "DAY=$day\n";
	print $OUT "SNAPNAME=\n";
	close($IN);
	close($OUT);

	copy_file_to_realpath($snaptmp, $BK_SNAP_CONF);
	unlink($origin_snap);
	unlink($snaptmp);

	return $taskid;
}

########################################################################################################
#  Set snapshot schedule
#  Input:   taskid        snapshot task id(3 digit number)
#           type          scheduling type(0=no scheduling, 1=hourly, 2=daily, 3=weekly)
#           hour          scheduling hour(required if type is 1, 2 or 3, 0~23)
#           minute        scheduling minute(required if type is 2 or 3, 0~59)
#           day           scheduling day(required if type is 3, 0=Sunday, 1=Monday, and so on)
#  Output:  -
#  Example: set_snapshot_schedule(001, 3, 22, 30, 0);  (Do snapshot task 001 at 22:30 every Sunday)
########################################################################################################
sub set_snapshot_schedule {
	my ($taskid, $type, $hour, $minute, $day)=@_;
	my ($origin_crontab, $crontabtmp, $action, $target);

	$origin_crontab = gen_random_filename("$CONF_CRONTAB");
	$crontabtmp = gen_random_filename("$CONF_CRONTAB");
	system("$CP_CMD -f $CONF_CRONTAB $origin_crontab");
	$action = "$PL_BKDOSNAPSHOT $taskid >/dev/null 2>/dev/null";
	$target = "$PL_BKDOSNAPSHOT $taskid";
	open(my $OUT, ">$crontabtmp");
	open(my $IN, "<$origin_crontab");
	while (<$IN>) {
		if (/$target/) {
		}
		else {
			print $OUT "$_";
		}
	}
	close($IN);

	if ($type == 1) {
		print $OUT "0 */$hour * * *	root	$action\n";
	}
	elsif ($type == 2) {
		print $OUT "$minute $hour * * *	root	$action\n";
	}
	elsif ($type == 3) {
		print $OUT "$minute $hour * * $day	root	$action\n";
	}
	close($OUT);

	copy_file_to_realpath($crontabtmp, $CONF_CRONTAB);
	unlink($origin_crontab);
	unlink($crontabtmp);
	return 0;
}

###########################################################
#  Get snapshot task list
#  Input:   -
#  Output:  array of snapshot tasks
#  Example: get_snapshot_tasks();
###########################################################
sub get_snapshot_tasks {
	my @snapshot_task=();
	
	my ($origin_snap, $TaskID, $VGNAME, $LVNAME, $SNAPCAP, $SnapCapByG, $AUTOEXTEND, $STATUS);
	$origin_snap = gen_random_filename("$BK_SNAP_CONF");
	system("$CP_CMD -f $BK_SNAP_CONF $origin_snap");
	open (my $TASK, "<$origin_snap");
	while (<$TASK>) {
		if (/\[(\S+)\]/) {
			if ($TaskID ne "") {
				# push data
				push @snapshot_task, {"taskid" => $TaskID, "vgname" => $VGNAME, "original_lvname" => $LVNAME, "original_sdname" => $SDNAME, "snapcap" => $SnapCapByG,
				                      "autoextend" => $AUTOEXTEND, "status" => $STATUS, "type" => $TYPE, "hour" => $HOUR, "minute" => $MINUTE, "day" => $DAY};
			}
			# clear data
			$TaskID = "";
			$VGNAME = "";
			$LVNAME = "";
			$SDNAME = "";
			$SNAPCAP = "";
			$SnapCapByG = 0;
			$AUTOEXTEND = "";
			$STATUS = "";
			$TYPE = "";
			$HOUR = "";
			$MINUTE = "";
			$DAY = "";
		
			$TaskID = $1;
		}
		elsif(/VGNAME\s*=\s*(\S+)/) {
			$VGNAME = $1;
		}
		elsif(/LVNAME\s*=\s*(\S+)/) {
			$LVNAME = $1;
		}
		elsif(/SDNAME\s*=\s*(\S+)/){
			 $SDNAME = $1;
		}
		elsif(/SNAPCAP\s*=\s*(\S+)/) {
			$SNAPCAP = $1;
			$SnapCapByG = calsize_to_M($SNAPCAP) / 1024.0 ;
		}
		elsif(/AUTOEXTEND\s*=\s*(\S+)/) {
			$AUTOEXTEND = $1;
		}
		elsif(/STATUS\s*=\s*(\S+)/) {
			$STATUS = $1;
		}
		elsif(/TYPE\s*=\s*(\S+)/) {
			$TYPE = $1;
		}
		elsif(/HOUR\s*=\s*(\S+)/) {
			$HOUR = $1;
		}
		elsif(/MINUTE\s*=\s*(\S+)/) {
			$MINUTE = $1;
		}
		elsif(/DAY\s*=\s*(\S+)/) {
			$DAY = $1;
		}
	}
	if ($TaskID ne "") {
		# push data
		push @snapshot_task, {"taskid" => $TaskID, "vgname" => $VGNAME, "original_lvname" => $LVNAME, "original_sdname" => $SDNAME, "snapcap" => $SnapCapByG,
		                      "autoextend" => $AUTOEXTEND, "status" => $STATUS, "type" => $TYPE, "hour" => $HOUR, "minute" => $MINUTE, "day" => $DAY};
	}
	close($TASK);
	unlink("$origin_snap");
	
	return @snapshot_task;
}

###########################################################
#  Delete all snapshot maked by input Share Disk
#  Input:   Share Disk name
#  Output:  0=OK, 1=one or more snapshot delete failed
#  Example: delete_snapshot_by_original_sd("PUBLIC");
###########################################################
sub delete_snapshot_by_original_sd {
	my ($original_sdname)=@_;
	my $rtnCode = 0;
		
	# get snapshot tasks
	my @snapshot_task=get_snapshot_tasks();
	my @delete_taskid=();
	for $info (@snapshot_task) {
		if ($info->{"original_sdname"} eq $original_sdname) {
			push @delete_taskid, $info->{"taskid"};
		}
	}
	if (@delete_taskid == 0) {
		return 0;
	}
	
	# delete snapshots
	my @snapshotlist = get_snapshot_list();
	my @failed_task=();
	for $snapshot (@snapshotlist) {
		if ($snapshot->{"taskid"} ~~ @delete_taskid) {
			my $snapshot_lvname = $snapshot->{"snap_lvname"};
			my $snapshot_sdname = $snapshot->{"snap_sdname"};
			my $vgname = $snapshot->{"vgname"};
			my $export = $snapshot->{"export"};
			my $taskid = $snapshot->{"taskid"};
			
			if ($export == 1) {
				close_snapshot($snapshot_sdname);
			}
			system("$UDEVADM_CMD control --stop-exec-queue >/dev/null 2>/dev/null");
			#system("$LVCHANGE_CMD -a n /dev/$vgname/$snapshot_lvname");
			my $result = system("$LVREMOVE_CMD -f /dev/$vgname/$snapshot_lvname >/dev/null 2>/dev/null");
			system("$UDEVADM_CMD control --start-exec-queue >/dev/null 2>/dev/null");
	
			if ($result != 0) {
				push @failed_task, $taskid;
				$rtnCode = 1;
			}
		}
	}
	
	# delete snapshot task
	my $delete_number = @delete_taskid - @failed_task;	
	my $origin_snap = gen_random_filename("$BK_SNAP_CONF");
	my $snaptmp = gen_random_filename("$BK_SNAP_CONF");
	system("$CP_CMD -f $BK_SNAP_CONF $origin_snap");

	my $in_section_flag = 0;
	open(my $OUT, ">$snaptmp");
	open(my $IN, "<$origin_snap");
	while (<$IN>) {
		if (/CREATED\s*=\s*(\d+)/) {
			my $created = $1;
			$created -= $delete_number;
			print $OUT "CREATED=$created\n";
			next;
		}
		if (/\[(\S+)\]/) {
			if ($1 ~~ @delete_taskid && !($1 ~~ @failed_task)) {
				$in_section_flag = 1;
			}
			else {
				$in_section_flag = 0;
			}
		}
		if ($in_section_flag == 0) {
			print $OUT "$_";
		}
	}
	close($IN);
	close($OUT);
	copy_file_to_realpath($snaptmp, $BK_SNAP_CONF);
	unlink($origin_snap);
	unlink($snaptmp);

	# sync snapshot config
	sync_snapshot_config();
	
	# delete task schedule
	my $origin_crontab = gen_random_filename("$CONF_CRONTAB");
	my $crontabtmp = gen_random_filename("$CONF_CRONTAB");
	system("$CP_CMD -f $CONF_CRONTAB $origin_crontab");
	open($OUT, ">$crontabtmp");
	open($IN, "<$origin_crontab");
	while (<$IN>) {
		if (/$PL_BKDOSNAPSHOT\s+(\S+)/) {
			if ($1 ~~ @delete_taskid && !($1 ~~ @failed_task)) {
			}
			else {
				print $OUT "$_";
			}
		}
		else {
			print $OUT "$_";
		}
	}
	close($IN);
	close($OUT);
	copy_file_to_realpath($crontabtmp, $CONF_CRONTAB);
	unlink($origin_crontab);
	unlink($crontabtmp);
	
	return $rtnCode;
}

###########################################################
#  Delete all snapshot task schedule
#  Input:   -
#  Output:  0=OK
#  Example: clear_snapshot_crontab();
###########################################################
sub clear_snapshot_crontab {
	my $origin_crontab = gen_random_filename("$CONF_CRONTAB");
	my $crontabtmp = gen_random_filename("$CONF_CRONTAB");
	system("$CP_CMD -f $CONF_CRONTAB $origin_crontab");
	open(my $OUT, ">$crontabtmp");
	open(my $IN, "<$origin_crontab");
	while (<$IN>) {
		if (/$PL_BKDOSNAPSHOT\s+(\S+)/) {
		}
		else {
			print $OUT "$_";
		}
	}
	close($IN);
	close($OUT);
	copy_file_to_realpath($crontabtmp, $CONF_CRONTAB);
	unlink($origin_crontab);
	unlink($crontabtmp);
	
	return 0;
}

###########################################################
#  Restore to factory default
#  Input:   -
#  Output:  0=OK
#  Example: snapshot_restore_to_default();
###########################################################
sub snapshot_restore_to_default {
	# delete task schedule
	clear_snapshot_crontab();
	
	# delete all snapshots
	my @snapshotlist = get_snapshot_list();
	for $snapshot (@snapshotlist) {
		my $vgname = $snapshot->{"vgname"};
		my $snapshot_lvname = $snapshot->{"snap_lvname"};
		my $snapshot_sdname = $snapshot->{"snap_sdname"};
		my $export = $snapshot->{"export"};
			
		if ($export == 1) {
			close_snapshot($snapshot_sdname);
		}
		system("$UDEVADM_CMD control --stop-exec-queue >/dev/null 2>/dev/null");
		#system("$LVCHANGE_CMD -a n /dev/$vgname/$snapshot_lvname");
		my $result = system("$LVREMOVE_CMD -f /dev/$vgname/$snapshot_lvname >/dev/null 2>/dev/null");
		system("$UDEVADM_CMD control --start-exec-queue >/dev/null 2>/dev/null");
	}
	
	# write new task file
	open (my $OUT, ">$BK_SNAP_CONF");
	print $OUT "CREATED=0\n";
	close ($OUT);
	
	# sync snapshot config
	sync_snapshot_config();
	
	return 0;
}

###########################################################
#  Get snapshot count of input Share Disk
#  Input:   sdname
#  Output:  snapshot count
#  Example: get_sd_snapshot_count("PUBLIC");
###########################################################
sub get_sd_snapshot_count {
	my ($sdname) = @_;
	
	my $count = 0;
	my @snapshot_task=get_snapshot_tasks();
	for $task (@snapshot_task) {
		if ($task->{"original_sdname"} eq $sdname) {
			$count += 1;
		}
	}
	
	return $count;
}

###########################################################
#  Get created snapshot count
#  Input:   -
#  Output:  created snapshot count
#  Example: get_created_snapshot_count();
###########################################################
sub get_created_snapshot_count {
	my $created = 0;
	my $origin_snap = gen_random_filename("$BK_SNAP_CONF");
	system("$CP_CMD -f $BK_SNAP_CONF $origin_snap");
	open(my $IN, "<$origin_snap");
	while (<$IN>) {
		if (/CREATED\s*=\s*(\d+)/) {
			$created = $1;
			last;
		}
	}
	close($IN);
	unlink("$origin_snap");
	
	return $created;
}

###########################################################
#  Check snapshot size is valid
#  Input:   vgname         volume group name
#           origin_sdsize  original Share Disk size(in MB)
#           snapcap_M      snapshot size(in MB)
#           quantity       snapshot quantity
#  Output:  0=OK, 1=snapshot size is too large, 2=snapshot size is too small, 3=Not enough Disk Pool size
#  Example: check_snapshot_size("vgname",10240,"2048,1);
###########################################################
sub check_snapshot_size {
	my ($vgname, $origin_sdsize, $snapcap_M, $quantity) = @_;
	
	# check Disk Pool free size
	my $volfree = 0;
	my @volinfo = get_vol_db();
	for $info (@volinfo) {
		if ($info->{"vgname"} eq $vgname) {
			$volfree = $info->{"volfree"};
			last;
		}
	}
	
	# check snapshot size (limit from 0.1*sd size(1GB) ~ sd size)
	if ($origin_sdsize < $snapcap_M) {
		return 1;
	}
	my $minimum_snap_size = $origin_sdsize*0.1;
	if ($minimum_snap_size < 1024.0) {
		$minimum_snap_size = 1024.0;
	}
	if ($snapcap_M < $minimum_snap_size) {
		return 2;
	}

	if ($volfree - $snapcap_M*$quantity < 0) {
		return 3;
	}
	
	return 0;
}

###########################################################
#  Sync snapshot config file
#  Input:   -
#  Output:  0=OK, 1=failed
#  Example: sync_snapshot_config();
###########################################################
sub sync_snapshot_config {
	my $realpath_conf = `$REALPATH_CMD $CONF_SNAPSHOT 2>/dev/null`;
	chomp($realpath_conf);
	my $res = SyncFileToRemote("", "$realpath_conf");
	return $res;
}

###########################################################
#  Take over all schedule snapshot
#  Input:   -
#  Output:  0=OK, 1=failed
#  Example: snapshot_failover();
###########################################################
sub snapshot_failover {
	# delete all task schedule
	clear_snapshot_crontab();
	
	# set all snapshot task
	my @snapshot_task = get_snapshot_tasks();
	for $task (@snapshot_task) {
		my $taskid = $task->{"taskid"};
		my $type = $task->{"type"};
		my $hour = $task->{"hour"};
		my $minute = $task->{"minute"};
		my $day = $task->{"day"};
		if ($type != 0) {
			set_snapshot_schedule($taskid, $type, $hour, $minute, $day);
		}
	}
	
	return 0;
}

###########################################################
#  Check snapshot task and remove if Share Disk is not exist.
#  Input:   -
#  Output:  0=OK
#  Example: snapshot_failover();
###########################################################
sub check_snapshot_task {
	# get all snapshot tasks
	my @snapshot_tasklist = get_snapshot_tasks();
	if (@snapshot_tasklist == 0) {
		return 0;
	}
	# get all Share Disks
	my @sdinfo = get_sd_db();
	
	# check if Share Disk exists
	my @checked_tasks = ();
	for $task (@snapshot_tasklist) {
		my $sdname = $task->{"original_sdname"};
		for $info (@sdinfo) {
			if ($info->{"sdname"} eq $sdname) {
				my $lvname = $info->{"lvname"};
				my $vgname = $info->{"vgname"};
				$task->{"original_lvname"} = $lvname;
				$task->{"vgname"} = $vgname;
				push @checked_tasks, $task;
				last;
			}
		}
	}
	
	# write back to config file
	my $created = @checked_tasks;
	$snaptmp = gen_random_filename("$BK_SNAP_CONF");
	open(my $OUT, ">$snaptmp");
	print $OUT "CREATED=$created\n";
	for $checked (@checked_tasks) {
		my $taskid     = $checked->{"taskid"};
		my $vgname     = $checked->{"vgname"};
		my $lvname     = $checked->{"original_lvname"};
		my $sdname     = $checked->{"original_sdname"};
		my $snapcap    = "$checked->{\"snapcap\"}"."G";
		my $autoextend = $checked->{"autoextend"};
		my $status     = $checked->{"status"};
		my $type       = $checked->{"type"};
		my $hour       = $checked->{"hour"};
		my $minute     = $checked->{"minute"};
		my $day        = $checked->{"day"};
		
		print $OUT "\[$taskid\]\n";
		print $OUT "VGNAME=$vgname\n";
		print $OUT "LVNAME=$lvname\n";
		print $OUT "SDNAME=$sdname\n";
		print $OUT "SNAPCAP=$snapcap\n";
		print $OUT "AUTOEXTEND=$autoextend\n";
		print $OUT "STATUS=$status\n";
		print $OUT "TYPE=$type\n";
		print $OUT "HOUR=$hour\n";
		print $OUT "MINUTE=$minute\n";
		print $OUT "DAY=$day\n";
		print $OUT "SNAPNAME=\n";
	}
	close($OUT);
	copy_file_to_realpath($snaptmp, $BK_SNAP_CONF);
	unlink($snaptmp);
	
	return 0;
}

###########################################################
#  Mount snapshot
#  Input:  sdname     snapshot sd name
#          vgname     snapshot vg name
#          lvname     snapshot lv name
#          encrypted  sanpshot is encrypted or not(0=no, 1=yes)
#          password  password for encrypted snapshot. Input "" for unknown password
#  Output:  0=OK, 1=Password incorrect, 2=Open encrypted snapshot failed, 3=Mount snapshot failed
#  Example: mount_snapshot("Public_snap", "password");
###########################################################
sub mount_snapshot {
	my ($sdname, $vgname, $lvname, $encrypted, $password) = @_;
	
	my $devname = "/dev/$vgname/$lvname";
	
	if ($encrypted == 1) {
		my $origin_lvname = "";
		my $snapshot_id = "";
		if ($lvname =~ /(\S+)TS(\S+)ID(\S+)/) {
			$origin_lvname = $1;
			$snapshot_id = $3;
		}
		my $origin_devname = "/dev/$vgname/$origin_lvname";
		my $encrypt_devname = "SNAP_ID"."$snapshot_id"."_crypt";
		my $ret = 0;	
		if (defined($password)) {
			$ret = LuksOpen($origin_devname, $password, $devname, $encrypt_devname);
		}
		else {
			$ret = LuksOpen($origin_devname, "", $devname, $encrypt_devname);
		}
		
		if ($ret == 3) {
			print "Encrypted snapshot \"$sdname\" password incorrect.\n";
			return 1;
		}
		elsif ($ret != 0) {
			print "Open encrypted snapshot \"$sdname\" failed.\n";
			return 2;
		}
		else {
			$devname = "/dev/mapper/$encrypt_devname";
		}
	}
	
	my $mount_folder = "$BK_SNAP_MOUNTFOLDER/$sdname";
	if (! -d "$mount_folder") {
		system("$MKDIR_CMD -p $mount_folder");
	}
	my $res = system("$MOUNT_GFS2_CMD $MOUNT_GFS2_OPT $devname $mount_folder");
	if ($res != 0) {
		print "Mount \"$sdname\" failed.\n";
		return 3;
	}
	system("$CHMOD_CMD 0777 $BK_SNAP_MOUNTFOLDER/$mountname");
	
	return 0;
}

###########################################################
#  Unmount snapshot
#  Input:  sdname     snapshot sd name
#          vgname     snapshot vg name
#          lvname     snapshot lv name
#          encrypted  sanpshot is encrypted or not(0=no, 1=yes)
#  Output:  0=OK, 1=Password incorrect, 2=Open encrypted snapshot failed, 3=Mount snapshot failed
#  Example: mount_snapshot("Public_snap", "password");
###########################################################
sub unmount_snapshot {
	my ($sdname, $vgname, $lvname, $encrypted) = @_;
	
	# make sure no proccess accessing this Share Disk
	kill_all_accessing_process("$BK_SNAP_MOUNTFOLDER/$sdname");
	
	# umount and delete mount folder
	my $res = system("$UNMOUNT_CMD -f -l $BK_SNAP_MOUNTFOLDER/$sdname");
	if ($res != 0) {
		print "Umount Snapshot \"$sdname\" error: $res.\n";
		return 1;
	}
	if (-d "$BK_SNAP_MOUNTFOLDER/$sdname") {
		system("$RMDIR_CMD $BK_SNAP_MOUNTFOLDER/$sdname");
	}
	
	# Do LucksClose if snapshot is encrypted
	if ($encrypted == 1) {
		my $original_lvname = "";
		my $taskid = "";
		if ($lvname =~ /(\S+)TS(\S+)ID(\S+)/) {
			$original_lvname = $1;
			$taskid = $3;
		}
		my $encrypt_name = "SNAP_ID"."$taskid"."_crypt";
		LuksClose("/dev/$vgname/$original_lvname", $encrypt_name);
	}
	
	return 0;
}

###########################################################
#  Change password for all snapshot taken by input Share Disk
#  Input:  vgname          Share Disk vg name
#          origin_lvname   Share Disk lv name
#          old_password    old password
#          new_password    new password
#  Output:  0=OK, other=Change password for 1 or more snapshot failed.
#  Example: change_encrypt_snapshot_password_by_sd("vgname", "lvname", "oldpassword", "newpassword")
###########################################################
sub change_encrypt_snapshot_password_by_sd {
	my ($vgname, $origin_lvname, $old_password, $new_password) = @_;
	
	my $ret = 0;
	my @snapshot_list = get_snapshot_list();
	for $snap (@snapshot_list) {
		if ($snap->{"vgname"} eq $vgname && $snap->{"original_lvname"} eq $origin_lvname) {
			my $snap_lvname = $snap->{"snap_lvname"};
			my $devname = "/dev/mapper/$vgname-$snap_lvname";
			$ret = LuksChangeKey($devname, $old_password, $new_password, 0);  # always no for automount snapshot
			if ($ret != 0) {
				my $snap_sdname = $snap->{"snap_sdname"};
				print "Change password for \"$snap_sdname\" failed.\n";
			}
		}
	}
	
	return $ret;
}

return 1;
