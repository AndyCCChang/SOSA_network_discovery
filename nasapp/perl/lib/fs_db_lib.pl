###################################################################
#  (C) Copyright Promise Technology Inc., 2013 All Rights Reserved
#  Name: lib/fs_db_lib.pl
#  Author: Kylin
#  Modifier:
#  Date: 2013/03/11
#  Description: Common functions for other perls.
###################################################################

require "/nasapp/perl/lib/db_lib.pl";
require "/nasapp/perl/lib/bk_ssh_lib.pl";    #SyncFileToRemote, SSHSystem
#require "/nasapp/perl/lib/fs_lib.pl";

########################################################################
#  input: $volume
#  output: 0=don't exist, 1=exist volume
#  desc: To see if exist given volume name
#  example: $exist = exist_vol_db("vol123"); # get only "vol123"
########################################################################
sub exist_vol_db {
	my ($volname) = @_;
	my $querySQL = "select count(0) from VOLUME where volname = '$volname';";
	my $count = exec_fs_sqlcount($querySQL);
	if ($count == 0) {
		return 0;
	}
	return 1;
}

########################################################################
#  input: $volname(optional)
#  output: @volAoH => Array of hash of volume information, or empty AoH
#  desc: get volume information (all or by volume name)
#  example: @volinfo = get_vol_db();         # get all volume information
#           @volinfo = get_vol_db("vol123"); # get only "vol123"
########################################################################
sub get_vol_db {
	my ($volname) = @_;
	my @volAoH = ();

	# Make query SQL command
	my $querySQL = "select volname, raid_type, prefer_ctrlid, reserve_ratio, vgname, vgsize, vgfree, CASE WHEN (vgfree-vgsize*reserve_ratio/100 > 0) THEN vgfree-vgsize*reserve_ratio/100 ELSE 0 END as volfree from VOLUME";
	if (defined($volname) && $volname ne "") {
		$querySQL .= " where volname = '$volname'";
	}
	$querySQL .= " order by volname;";

	# Make query SQL file
	my $sqlfile = gen_random_filename("");
	open(my $OUT, ">$sqlfile");
	print $OUT ".separator \"\x4 : \x4\"\n";
	print $OUT "$querySQL\n";
	close($OUT);
	
	# Query database
	my $tmpfile = gen_random_filename("");
	my $dbres = exec_fs_sqlfile($sqlfile, $tmpfile);
	#print "deres = $dbres\n";
	if ($dbres != 0) {
		print "Get volume information error.\n";
		unlink($tmpfile);
		return @volAoH;
	}
	
	# Read from tmpfile, parse output data and push to AoH structure
	open(my $IN, $tmpfile);
	while(<$IN>) {
		#chomp($_); --> chomp causes split() be unfunctional(miss last empty field)
		my @tempstr = split(chr(4).' : '.chr(4), $_);
		if ($#tempstr == 7) {
			chomp($tempstr[7]); # chmop last field to avoid the value become "\n"
			push @volAoH, {"volname" => $tempstr[0], "raid_type" => $tempstr[1], 
			               "prefer_ctrlid" => $tempstr[2], "reserve_ratio" => $tempstr[3], 
						   "vgname" => $tempstr[4], "vgsize" => $tempstr[5],
						   "vgfree" => $tempstr[6], "volfree" => $tempstr[7]};
		}
	}
	close($IN);
	unlink($tmpfile);

	return @volAoH;
}

########################################################################
#  input: $volname, $raid_type, $prefer_ctrlid, $reserve_ratio, $vgname, $vgsize, $vgfree
#  output: $res: 0=OK, 1=Fail, 19=volname already exists
#  desc: Create new NAS volume
#  example: create_vol_db("vol123", "raid 5", 1, 10, "vgname", 100, 100);
########################################################################
sub create_vol_db {
	my ($volname, $raid_type, $prefer_ctrlid, $reserve_ratio, $vgname, $vgsize, $vgfree) = @_;
	my $sqlcmd = "insert into VOLUME (volname, raid_type, prefer_ctrlid, reserve_ratio, vgname, vgsize, vgfree) values (";
	$sqlcmd .= "'$volname', '$raid_type', $prefer_ctrlid, $reserve_ratio, '$vgname', $vgsize, $vgfree);";
	my $dbres = exec_fs_sqlcmd($sqlcmd);
	# sync /nasdata/config/etc/fs.db
	SyncFileToRemote("", "$CONF_DB_FS");
	return $dbres;
}

########################################################################
#  input: $volname, $hashdata
#  output: $res: 0=OK, 1=Fail
#  desc: Modify data of NAS volume
#  example: %hashdata = (); $hashdata{"raid_type"} = "raid 6"; $hashdata{"reserve_ratio"} = 20;
#           modify_vol_db("vol123", \%hashdata);
########################################################################
sub modify_vol_db {
	my ($volname, $hashdata) = @_;
	my %data = %$hashdata;
	my $flag = 0;
	my $sqlcmd = "update VOLUME set";
	my $upd_set;
	foreach $key (keys %data) {
		#print "$key = $data{$key}\n";
		if ($key eq "raid_type") {
			$upd_set .= " raid_type = '$data{$key}',";
		}
		elsif ($key eq "prefer_ctrlid") {
			$upd_set .= " prefer_ctrlid = $data{$key},";
		}
		elsif ($key eq "reserve_ratio") {
			$upd_set .= " reserve_ratio = $data{$key},";
		}
		elsif ($key eq "vgname") {
			$upd_set .= " vgname = '$data{$key}',";
		}
		elsif ($key eq "vgsize") {
			$upd_set .= " vgsize = $data{$key},";
		}
		elsif ($key eq "vgfree") {
			$upd_set .= " vgfree = $data{$key},";
		}
	}
	chop($upd_set);
	$sqlcmd .= $upd_set." where volname = '$volname'";

	my $dbres = exec_fs_sqlcmd($sqlcmd);
	# sync /nasdata/config/etc/fs.db
	SyncFileToRemote("", "$CONF_DB_FS");
	return $dbres;
}

########################################################################
#  input: None -> delete all volume in DB
#  input: $volname
#  output: $res: 0=OK, 1=Fail
#  desc: Delete NAS volume from database
#  example: delete_vol_db("vol_01");
########################################################################
sub delete_vol_db {
	my ($volname) = @_;

	my $sqlcmd = "delete from VOLUME";
	if (defined($volname)) {
		$sqlcmd .= " where volname = '$volname'";
	}
	$sqlcmd .= ";";

	my $dbres = exec_fs_sqlcmd($sqlcmd);

	# sync /nasdata/config/etc/fs.db
	SyncFileToRemote("", "$CONF_DB_FS");

	return $dbres;
}

########################################################################
#  input: $sdname
#  output: 0=don't exist, 1=exist sdname
#  desc: To see if exist given sdname
#  example: $exist = exist_sd_db("vol123"); # get only "vol123"
########################################################################
sub exist_sd_db {
	my ($sdname) = @_;
	my $querySQL = "select count(0) from SHARE_DISK where sdname = '$sdname';";
	my $count = exec_fs_sqlcount($querySQL);
	if ($count == 0) {
		return 0;
	}
	return 1;
}

########################################################################
#  input: $sdname(optional)  $list_hidden(optinal)
#  output: @sdAoH => Array of hash of share disk information, or empty AoH
#  desc: get share disk information (all or by share disk name)
#  example: @sdinfo = get_sd_db();         # get all share disk information
#           @sdinfo = get_sd_db("public"); # get only "public"
########################################################################
sub get_sd_db {
	my ($sdname,$list_hidden) = @_;
	my @sdAoH = ();
	

	# Make query SQL command
	my $querySQL  = "select A.volname, A.sdname, A.lvname, A.lvsize, A.type, A.encrypted, A.defperm, A.smb_share, A.afp_share, A.ftp_share, ";
	   $querySQL .= "A.nfs_share, A.webdav_share, A.last_check_start_time, A.last_check_stop_time, A.last_check_status, ";
	   $querySQL .= "A.last_check_spend_time, B.vgname, B.vgfree, CASE WHEN (vgfree-vgsize*reserve_ratio/100 > 0) THEN B.vgfree-B.vgsize*B.reserve_ratio/100 ELSE 0 END as volfree ";
	   $querySQL .= "from SHARE_DISK as A left join VOLUME as B on A.volname = B.volname ";
	   $querySQL .= "where 1=1 ";
	if (defined($sdname) && $sdname ne "") {
		$querySQL .= "and sdname = '$sdname'";
	}
	if (!defined($list_hidden) || $list_hidden == 0) {
		$querySQL .= "and type != 'hidden'";
	}
		   
	$querySQL .= " order by A.volname, A.sdname;";

	# Make query SQL file
	my $sqlfile = gen_random_filename("");
	open(my $OUT, ">$sqlfile");
	print $OUT ".separator \"\x4 : \x4\"\n";
	print $OUT "$querySQL\n";
	close($OUT);
	
	# Query database
	my $tmpfile = gen_random_filename("");
	my $dbres = exec_fs_sqlfile($sqlfile, $tmpfile);
	#print "deres = $dbres\n";
	if ($dbres != 0) {
		print "Get sharedisk information error.\n";
		unlink($tmpfile);
		return @sdAoH;
	}
	my %allow_ips_data=get_nfs_allowip_db();	
	
	# Read from tmpfile, parse output data and push to AoH structure
	open(my $IN, $tmpfile);
	while(<$IN>) {
		# chomp($_); --> chomp causes split() be unfunctional(miss last empty field)
		my @tempstr = split(chr(4).' : '.chr(4), $_);
		my $allow_ips_str="";
		if ($#tempstr == 18) {
			chomp($tempstr[18]); # chmop last field to avoid the value become "\n"
			if(exists($allow_ips_data{$tempstr[1]})){
				$allow_ips_str=$allow_ips_data{$tempstr[1]};
			}
			push @sdAoH, {"volname" => $tempstr[0], 
                          "sdname" => $tempstr[1], 
			              "lvname" => $tempstr[2],
						  "lvsize" => $tempstr[3],
                          "type" => $tempstr[4], 
						  "encrypted" => $tempstr[5],
                          "defperm" => $tempstr[6],
						  "smb_share" => $tempstr[7],
                          "afp_share" => $tempstr[8], 
                          "ftp_share" => $tempstr[9], 
			              "nfs_share" => $tempstr[10],
                          "webdav_share" => $tempstr[11], 
						  "last_check_start_time" => $tempstr[12],
                          "last_check_stop_time" => $tempstr[13],
						  "last_check_status" => $tempstr[14],
                          "last_check_spend_time" => $tempstr[15],
                          "vgname" => $tempstr[16],
                          "vgfree" => $tempstr[17],
						  "volfree" => $tempstr[18],
						  "nfs_allow_ips"=>$allow_ips_str};
		}
	}
	close($IN);
	unlink($tmpfile);

	return @sdAoH;
}

########################################################################
#  input: $volname, $sdname, $lvname, $lvsize, $type, $encrypted, $defperm, $smb_share, $afp_share, $ftp_share, $nfs_share, $webdav_share, 
#         $last_check_start_time, $last_check_stop_time, $last_check_status, $last_check_spend_time
#         $allow_ip_file(optional)
#  output: $res: 0=OK, 1=Fail, 19=sdname already exists
#  desc: Create new NAS share disk
#  example: create_sd_db("public", "vol_name", "lv-1234", "standard", 0, 2, 1, 1, 1, 1, 1, "", "", 2, "");
########################################################################
sub create_sd_db {
	my ($volname, $sdname, $lvname, $lvsize, $type, $encrypted, $defperm, $smb_share, $afp_share, $ftp_share, $nfs_share, $webdav_share, $last_check_start_time, $last_check_stop_time, $last_check_status, $last_check_spend_time, $allow_ip_file) = @_;
	my $sqlcmd = "insert into SHARE_DISK (volname, sdname, lvname, lvsize, type, encrypted, defperm, smb_share, afp_share, ftp_share, nfs_share, webdav_share, last_check_start_time, last_check_stop_time, last_check_status, last_check_spend_time) values (";
	$sqlcmd .= "'$volname', '$sdname', '$lvname', $lvsize, '$type', $encrypted, $defperm, $smb_share, $afp_share, $ftp_share, $nfs_share, $webdav_share, '$last_check_start_time', '$last_check_stop_time', $last_check_status, '$last_check_spend_time');";

	my $sqlfile = gen_random_filename("");
	my ($OUT,$IN);
	open($OUT, ">$sqlfile");
	print $OUT "BEGIN TRANSACTION;\n";
	print $OUT "$sqlcmd\n";
	if (-f $allow_ip_file) {
		open($IN, $allow_ip_file);
		while (<$IN>) {
			my $allow_ip = $_;
			chomp($allow_ip);
			if ($allow_ip ne "") {
				print $OUT "insert into NFS_ALLOW_IP (sdname, allow_ip) values ('$sdname', '$allow_ip');\n";
			}
		}
		close($IN);
		unlink($allow_ip_file);
	}
	print $OUT "COMMIT;\n";
	close($OUT);

	my $dbres = exec_fs_sqlfile($sqlfile);
	# sync /nasdata/config/etc/fs.db
	SyncFileToRemote("", "$CONF_DB_FS");

	return $dbres;
}

########################################################################
#  input: $sdname, $hashdata
#  output: $res: 0=OK, 1=Fail
#  desc: Modify data of NAS share disk
#  example: %hashdata = (); $hashdata{"defperm"} = 2; $hashdata{"smb_share"} = 20;
#           modify_sd_db("public", \%hashdata);
########################################################################
sub modify_sd_db {
	my ($sdname, $hashdata) = @_;
	my %data = %$hashdata;
	my $flag = 0;
	my $sqlcmd = "update SHARE_DISK set";
	my $upd_set;
	foreach $key (keys %data) {
		#print "$key = $data{$key}\n";
		if ($key eq "volname") {
			$upd_set .= " volname = '$data{$key}',";
		}
		elsif ($key eq "lvname") {
			$upd_set .= " lvname = '$data{$key}',";
		}
		elsif ($key eq "lvsize") {
			$upd_set .= " lvsize = $data{$key},";
		}
		elsif ($key eq "type") {
			$upd_set .= " type = '$data{$key}',";
		}
		elsif ($key eq "encrypted") {
			$upd_set .= " encrypted = $data{$key},";
		}
		elsif ($key eq "defperm") {
			$upd_set .= " defperm = $data{$key},";
		}
		elsif ($key eq "smb_share") {
			$upd_set .= " smb_share = $data{$key},";
		}
		elsif ($key eq "afp_share") {
			$upd_set .= " afp_share = $data{$key},";
		}
		elsif ($key eq "ftp_share") {
			$upd_set .= " ftp_share = $data{$key},";
		}
		elsif ($key eq "nfs_share") {
			$upd_set .= " nfs_share = $data{$key},";
		}
		elsif ($key eq "webdav_share") {
			$upd_set .= " webdav_share = $data{$key},";
		}
		elsif ($key eq "last_check_start_time") {
			$upd_set .= " last_check_start_time = '$data{$key}',";
		}
		elsif ($key eq "last_check_stop_time") {
			$upd_set .= " last_check_stop_time = '$data{$key}',";
		}
		elsif ($key eq "last_check_status") {
			$upd_set .= " last_check_status = $data{$key},";
		}
		elsif ($key eq "last_check_spend_time") {
			$upd_set .= " last_check_spend_time = '$data{$key}',";
		}
	}
	chop($upd_set);
	$sqlcmd .= $upd_set." where sdname = '$sdname'";

	my $dbres = exec_fs_sqlcmd($sqlcmd);
	# sync /nasdata/config/etc/fs.db
	SyncFileToRemote("", "$CONF_DB_FS");

	return $dbres;
}

########################################################################
#  input: $sdname(must)
#  output: $res: 0=OK, 1=Fail
#  desc: Delete share disk from database
#  example: delete_sd_db("public");
########################################################################
sub delete_sd_db {
	my ($sdname) = @_;

	# Should input sdname parameter or return error
	if (!defined($sdname) || $sdname eq "") {
		return 1;
	}
	my $dbres = 0;
	
	# delete share disk data in fs db
	my $sqlfile = gen_random_filename("");
	open(my $OUT, ">$sqlfile");
	print $OUT "BEGIN TRANSACTION;\n";
	print $OUT "delete from SHARE_DISK where sdname = '$sdname';\n";
	print $OUT "delete from NFS_ALLOW_IP where sdname = '$sdname';\n";
	print $OUT "COMMIT;\n";
	close($OUT);
	$dbres += exec_fs_sqlfile($sqlfile);
	
	# delete share disk data in acc db
	$sqlfile = gen_random_filename("");
	open(my $OUT, ">$sqlfile");
	print $OUT "BEGIN TRANSACTION;\n";
	print $OUT "delete from QUOTA where sdName = '$sdname';\n";
	print $OUT "delete from QUOTA_UNSET where sdName = '$sdname';\n";
	print $OUT "delete from PERMISSION where sdName = '$sdname';\n";
	print $OUT "delete from PERM_UNSET where sdName = '$sdname';\n";
	print $OUT "COMMIT;\n";
	close($OUT);
	$dbres += exec_acc_sqlfile($sqlfile);

	# sync /nasdata/config/etc/fs.db
	SyncFileToRemote("", "$CONF_DB_FS");
	SyncFileToRemote("", "$CONF_DB_USER");

	return $dbres;
}

########################################################################
#  input:  $sdname    share disk name(string)
#          $defperm   default permission (0=unset, 1=deny, 2=read only, 3=read/write)
#  output: $res: 0=OK, 1=Fail
#  desc: Update defperm of SHARE_DISK table
#  example: update_sd_defperm_db("public", 1);
########################################################################
sub update_sd_defperm_db {
	my ($sdname, $defperm) = @_;

	my $sqlcmd = "update SHARE_DISK set defperm = $defperm where sdname = '$sdname';";
	my $dbres = exec_fs_sqlcmd($sqlcmd);
	# sync /nasdata/config/etc/fs.db
	SyncFileToRemote("", "$CONF_DB_FS");

	return $dbres;
}
########################################################################
#  input:  X
#  output: @sdnameAry => Array share disk name, or empty array
#  desc: Get share disk name from SHARE_DISK TABLE
#  example: get_sdname_db();
########################################################################
sub get_sdname_db {
	my @sdnameAry = ();
	# Make query SQL command
	my $querySQL  = "select sdname from SHARE_DISK;";
	# Make query SQL file
	my $sqlfile = gen_random_filename("");
	my ($OUT,$IN);
	open($OUT, ">$sqlfile");
	print $OUT ".separator \"\x4 : \x4\"\n";
	print $OUT "$querySQL\n";
	close($OUT);
	
	# Query database
	my $tmpfile = gen_random_filename("");
	my $dbres = exec_fs_sqlfile($sqlfile, $tmpfile);
	#print "deres = $dbres\n";
	if ($dbres != 0) {
		print "Get sharedisk information error.\n";
		unlink($tmpfile);
		return @sdnameAry;
	}
	
	# Read from tmpfile, parse output data and push to AoH structure
	open($IN, $tmpfile);
	while(<$IN>) {
		# chomp($_); --> chomp causes split() be unfunctional(miss last empty field)
		my @tempstr = split(chr(4).' : '.chr(4), $_);
		if ($#tempstr == 0) {
			chomp($tempstr[0]); # chmop last field to avoid the value become "\n"
			push @sdnameAry,$tempstr[0];
		}
	}
	close($IN);
	unlink($tmpfile);
	return @sdnameAry;
}

sub get_sdname_share {
	my ($sdname) = @_;
	my @sdnameAry = ();
	# Make query SQL command
	my $querySQL  = "select A.sdname,A.smb_share, A.afp_share, A.ftp_share,A.nfs_share, A.webdav_share from SHARE_DISK as A where sdname = '$sdname';";
	# Make query SQL file
	my $sqlfile = gen_random_filename("");
	my ($OUT,$IN);
	open($OUT, ">$sqlfile");
	print $OUT ".separator \"\x4 : \x4\"\n";
	print $OUT "$querySQL\n";
	close($OUT);
	
	# Query database
	my $tmpfile = gen_random_filename("");
	my $dbres = exec_fs_sqlfile($sqlfile, $tmpfile);
	#print "deres = $dbres\n";
	if ($dbres != 0) {
		print "Get sharedisk information error.\n";
		unlink($tmpfile);
		return @sdnameAry;
	}
	
	# Read from tmpfile, parse output data and push to AoH structure
	open($IN, $tmpfile);
	while(<$IN>) {
		# chomp($_); --> chomp causes split() be unfunctional(miss last empty field)
		my @tempstr = split(chr(4).' : '.chr(4), $_);
		if ($#tempstr == 5) {
			chomp($tempstr[5]); # chmop last field to avoid the value become "\n"
			push @sdnameAry,{'sdname'=>$tempstr[0],'smb_share'=>$tempstr[1],'afp_share'=>$tempstr[2],'ftp_share'=>$tempstr[3],'nfs_share'=>$tempstr[4],'webdav_share'=>$tempstr[5]};
		}
	}
	close($IN);
	unlink($tmpfile);
	return @sdnameAry;
}


########################################################################
#  input:  X
#  output: @data => Array of Hash {'sdname'} , {'type'}
#  desc: Get share disk name ,typefrom SHARE_DISK TABLE
#  example: get_sdname_type_db();
########################################################################
sub get_sdname_type_db {
	my @data = ();
	# Make query SQL command
	my $querySQL  = "select sdname,type from SHARE_DISK;";
	# Make query SQL file
	my $sqlfile = gen_random_filename("");
	my ($OUT,$IN);
	open($OUT, ">$sqlfile");
	print $OUT ".separator \"\x4 : \x4\"\n";
	print $OUT "$querySQL\n";
	close($OUT);
	
	# Query database
	my $tmpfile = gen_random_filename("");
	my $dbres = exec_fs_sqlfile($sqlfile, $tmpfile);
	#print "deres = $dbres\n";
	if ($dbres != 0) {
		unlink($tmpfile);
		return @data;
	}
	
	# Read from tmpfile, parse output data and push to AoH structure
	open($IN, $tmpfile);
	while(<$IN>) {
		# chomp($_); --> chomp causes split() be unfunctional(miss last empty field)
		my @tempstr = split(chr(4).' : '.chr(4), $_);
		if ($#tempstr == 1) {
			chomp($tempstr[1]); # chmop last field to avoid the value become "\n"
			push @data,{'sdname'=>$tempstr[0],'type'=>$tempstr[1]};
		}
	}
	close($IN);
	unlink($tmpfile);
	return @data;
}
########################################################################
#  input:  X
#  output: %nfs_hash => Hash of nfs allow ip of Share Disk of empty
#  desc: Get nfs allow ip information from Table NFS_ALLOW_IP
#  example: { "SD1"=>'*.*.*.* , 192.168.207.1', "SD2"=>'*.*.*.*' }
########################################################################
sub get_nfs_allowip_db{
	my %nfs_hash=();
	my $nfs_sqlfile = gen_random_filename("");
	my $nfs_querySQL= "select sdname,allow_ip||'+'||nfs_option from NFS_ALLOW_IP;";
	open(my $NFS_ALLOW, ">$nfs_sqlfile");
	print $NFS_ALLOW ".separator \"".chr(4).' : '.chr(4)."\"\n";
	print $NFS_ALLOW "$nfs_querySQL\n";
	close($NFS_ALLOW);
	# Query database
	my $nfs_tmpfile = gen_random_filename("");
	my $nfs_dbres = exec_fs_sqlfile($nfs_sqlfile, $nfs_tmpfile);
	if ($nfs_dbres != 0) {
		print "Get nfs information error.\n";
		unlink($nfs_tmpfile);
		return %nfs_hash;
	}
	# Read from tmpfile, parse output data and push to AoH structure
	open(my $IN, $nfs_tmpfile);
	while(<$IN>) {
		my @tempstr = split(chr(4).' : '.chr(4), $_);
		if ($#tempstr == 1) {
			chomp($tempstr[1]); # chmop last field to avoid the value become "\n"
			if(exists($nfs_hash{$tempstr[0]})){
				$nfs_hash{$tempstr[0]}=$nfs_hash{$tempstr[0]}.",".$tempstr[1];
			}else{
				$nfs_hash{$tempstr[0]}=$tempstr[1];
			}
		}
	}
	close($IN);
	unlink($nfs_tmpfile);
	return %nfs_hash;
}
return 1;  # this is required.
