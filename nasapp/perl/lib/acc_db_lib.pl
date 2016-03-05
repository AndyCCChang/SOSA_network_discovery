###################################################################
#  (C) Copyright Promise Technology Inc., 2013 All Rights Reserved
#  Name: lib/acc_db_lib.pl
#  Author: Kylin
#  Modifier:
#  Date: 2013/1/3
#  Description: Common functions for other perls.
###################################################################

require "/nasapp/perl/lib/db_lib.pl";
require "/nasapp/perl/lib/dir_path.pl";
require "/nasapp/perl/lib/fs_lib.pl";
require "/nasapp/perl/lib/log_db_lib.pl";

#user/group name max length
$MAX_MULTI_LENGTH = 26;
$MAX_INDEX_LENGTH = 4;
$MAX_LENGTH = 30;
$PWD_MIN_LENGTH = 6;
$PWD_MAX_LENGTH = 16;
# uid for local user must in 1000~10999, total 10000 users
$MIN_UID = 1000;
#$MAX_UID = 10999;
# uid for local user must in 1000~10999, total 10000 group
$MIN_GID = 1000;
#$MAX_GID = 10999;
# idmap for domain
$MIN_AD_UID = 30001;
$MIN_AD_GID = 30001;
# Illegal Local User
%ILLEGAL_USER = ("root" => 0, "daemon" => 1, "sshd" => 74, "nobody" => 99, "messagebus" => 110, "administrator" => 300);
# Illegal Local Group
%ILLEGAL_GROUP = ("root" => 0, "bin" => 1, "daemon" => 2, "sys" => 3, "adm" => 4, "tty" => 5, "disk" => 6, "mem" => 8,
                  "kmem" => 9, "wheel" => 10, "uucp" => 14, "utmp" => 22, "rpcuser" => 29, "rpc" => 32, "ntp" => 38,
				  "ftp" => 50, "nobody" => 99, "users" => 100, "administrator" => 300);

########################################################################
#  input: $gid, $grpName
#  output: $res
#  desc: Query db to get members of group, then set to system by gpasswd command
########################################################################
sub set_group_users {
	my ($gid, $grpName)= @_;
	$tmpfile = gen_random_filename("");
	my $querySQL = "select A.userName from LO_USER as A inner join LO_RELATION as B on A.uid = B.uid where B.gid = $gid;";
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		naslog($LOG_ACC_NASGROUP,$LOG_ERROR,"28","Set group's user fail");
		unlink($tmpfile);
		return $dbres;
	}
	
	$argfile = gen_random_filename("");
	$first = 1;
	open(my $IN, "<$tmpfile");
	open(my $OUT, ">$argfile");
	print $OUT "-M\0";
	while(<$IN>) {
		$userName = $_;
		chomp $userName;
		if ($first == 1) {
			print $OUT $userName;
			$first = 0;
		}
		else {
			print $OUT ",$userName";
		}
	}
	print $OUT "\0$grpName\0";
	close($IN);
	close($OUT);
	unlink($tmpfile);
	print "$CAT_CMD $argfile | $MXARGS_CMD -0 $GPASSWD_CMD\n";
	$ret = system("$CAT_CMD $argfile | $MXARGS_CMD -0 $GPASSWD_CMD");
	if ($ret != 0) {
		naslog($LOG_ACC_NASGROUP,$LOG_ERROR,"42","Set group [$grpName] member fail.");
	}
	unlink($argfile);

	# backup /etc/group & /etc/gshadow to data area
	# bk_group_conf(); # do it at acc_addgroup_sys.pl

	return $ret;
}

########################################################################
#  input: $search
#  output: [$count]
#  desc: get count of total local users in database.
########################################################################
sub get_users_count {
	my $search = @_[0];
	my $count = 0;
	my $likeSQL = "";
	if (defined($search) && $search ne "") {
		$likeSQL = "where userName like '$search%'";
	}

	my $querySQL = "select count(0) from LO_USER $likeSQL;";
	$count = exec_acc_sqlcount($querySQL);

	return $count;
}

########################################################################
#  input: $search
#  output: [$count]
#  desc: get count of total local users in database.
########################################################################
sub get_groups_count {
	my $search = @_[0];
	my $count = 0;
	my $likeSQL = "";
	if (defined($search) && $search ne "") {
		$likeSQL = "where grpName like '$search%'";
	}

	my $querySQL = "select count(0) from LO_GROUP $likeSQL;";
	$count = exec_acc_sqlcount($querySQL);

	return $count;
}

########################################################################
#  input: [$uid] string
#  output: [$exist] 0: absence 1: exist
#  desc: To see if the uid exists
########################################################################
sub exist_uid {
	my $uid = @_[0];
	my $exist = 0;
	$tmpfile = gen_random_filename("");
	my $querySQL = "select uid from LO_USER where uid='$uid';";
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		unlink($tmpfile);
		return 0;
	}
	open(my $IN, "<$tmpfile");
	while (<$IN>) {
		if (/(\d+)/) {
			$exist = 1;
		}
		last;
	}
	close($IN);
	unlink($tmpfile);
	return $exist;
}

########################################################################
#  input: [$uid] string
#         [$serch] string
#  output: [$count] Return count of group members
#  desc: Get count of group members
########################################################################
sub get_group_member_count {
	my $gid = @_[0];
	my $search = @_[1];
	
	my $likeSQL = "";
	if ($search ne "") {
		$likeSQL = "and userName like '$search%'";
	}
	
	my $querySQL = "select count(0) from LO_USER as A inner join LO_RELATION as B on A.uid = B.uid where B.gid = $gid $likeSQL;";
	my $count = exec_acc_sqlcount($querySQL);
	
	return $count;
}

########################################################################
#  input: [$token] string
#         [$serch] string
#  output: [$count] Return count of group members
#  desc: Get count of unset group members
########################################################################
sub get_unset_groupmember_count {
	my $token = @_[0];
	my $search = @_[1];
	
	my $likeSQL = "";
	if ($search ne "") {
		$likeSQL = "and userName like '$search%'";
	}
	
	my $querySQL = "select count(0) from LO_GRPMEM_UNSET where token = '$token' $likeSQL;";
	my $count = exec_acc_sqlcount($querySQL);
	
	return $count;
}

########################################################################
#  input: $sdname, $source, $page, $pageSize, $search, $outfile
#  output: 0=OK, others=failed with error code
#  desc: get group member list and dump to outfile
########################################################################
sub get_unset_groupmember {
	my $token = @_[0];
	my $page = @_[1];
	my $pageSize = @_[2];
	my $search = @_[3];
	my $sort = @_[4];
	my $direct = @_[5];
	my $outfile = @_[6];
	
	my $likeSQL = "";
	if ($search ne "") {
		$likeSQL = "and userName like '$search%'";
	}
	my $start = ($page - 1) * $pageSize;
	
	my $querySQL = "select belong, uid, userName, description from LO_GRPMEM_UNSET where token = '$token' $likeSQL order by $sort $direct limit $start, $pageSize;";
	#print "querySQL = $querySQL\n";
	my $sqlfile = gen_random_filename("");
	open(my $OUT, ">$sqlfile");
	print $OUT ".header on\n";
	print $OUT ".separator \"\x4 | \x4\"\n";
	print $OUT "$querySQL\n";
	close($OUT);
	
	# execute query SQL command, dump to $outfile directly
	$dbres = exec_acc_sqlfile($sqlfile, $outfile);	
	
	return $dbres;
}

########################################################################
#  input: $token
#  output: 0=OK, others=failed with error code
#  desc: delete unset permission by token.
########################################################################
sub del_unset_groupmember {
	my ($token) = @_;
	chomp($token);
	
	my $deleteSQL = "delete from LO_GRPMEM_UNSET where token = '$token';";
	# execute SQL command
	my $dbres = exec_acc_sqlcmd($deleteSQL);
	if ($dbres != 0) {
		naslog($LOG_ACC_NASGROUP,$LOG_ERROR,"29","Delete internal server entry fail");
	}
	return $dbres;
}

########################################################################
#  input: [$savefile] string
#         [$token] string
#  output: 0=OK, others=failed with error code
#  desc: Set savefile into unset group member
########################################################################
sub set_unset_groupmember {
	my $savefile = @_[0];
	my $token = @_[1];
	
	my $sqlfile = gen_random_filename("");
	open(my $OUT, ">$sqlfile");
	print $OUT "BEGIN TRANSACTION;\n";
	open(my $IN, "<$savefile");
	while (<$IN>) {
		if (/(\d+),(\d+)/) {
			my $uid = $1;
			my $belong = $2;
			print $OUT "update LO_GRPMEM_UNSET set belong = $belong where uid = $uid and token = '$token';\n";
		}
	}
	print $OUT "COMMIT;\n";
	close($IN);
	close($OUT);

	# execute SQL command
	my $dbres = exec_acc_sqlfile($sqlfile);
	if ($dbres != 0) {
		naslog($LOG_ACC_NASGROUP,$LOG_ERROR,"45","exec sqlfile (update LO_GRPMEM_UNSET) error");
	}
	unlink($savefile);
	
	return $dbres;
}

########################################################################
#  input: [$gid] integer
#  output: 0=OK, others=failed with error code
#  desc: Delete all group member
########################################################################
sub del_group_member {
	my $gid = @_[0];
	
	my $deleteSQL = "delete from LO_RELATION where gid = $gid;";
	# execute SQL command
	my $dbres = exec_acc_sqlcmd($deleteSQL);
	if ($dbres != 0) {
		naslog($LOG_ACC_NASGROUP,$LOG_ERROR,"48","Delete internal server entry fail");
	}
	return $dbres;
}

########################################################################
#  input: [$uid] string
#  output: [$userName] Return user name or empty string
#  desc: To see if the uid exists
########################################################################
sub get_userName_by_uid {
	my $uid = @_[0];
	my $userName = "";
	$tmpfile = gen_random_filename("");
	my $querySQL = "select userName from LO_USER where uid='$uid';";
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		naslog($LOG_ACC_NASUSER,$LOG_WARNING,"31","Get user name from internal server fail.");
		unlink($tmpfile);
		return 0;
	}
	open(my $IN, "<$tmpfile");
	while (<$IN>) {
		$userName = $_;
		chomp $userName;
		last;
	}
	close($IN);
	unlink($tmpfile);
	return $userName;
}
########################################################################
#  input: [$uname] string
#  output: [$id] Return user id or empty string
#  desc: To see if the username exists
########################################################################
sub get_userID_by_userName {
	my $uname = @_[0];
	my $id = 0;
	$tmpfile = gen_random_filename("");
	my $querySQL = "select uid from LO_USER where userName='$uname';";
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		unlink($tmpfile);
		return 0;
	}
	open(my $IN, "<$tmpfile");
	while (<$IN>) {
		$id = $_;
		chomp $id;
		last;
	}
	close($IN);
	unlink($tmpfile);
	return $id;
}
########################################################################
#  input: [$userName] string
#  output: [$exist] 0: absence 1: exist
#  desc: To see if the user name exists
########################################################################
sub exist_userName {
	my $userName = @_[0];
	my $exist = 0;
	$tmpfile = gen_random_filename("");
	my $querySQL = "select uid from LO_USER where userName='$userName';";
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		unlink($tmpfile);
		return 0;
	}
	open(my $IN, "<$tmpfile");
	while (<$IN>) {
		if (/(\d+)/) {
			$exist = 1;
		}
		last;
	}
	close($IN);
	unlink($tmpfile);
	return $exist;
}

########################################################################
#  input: [$gid] string
#  output: [$exist] 0: absence 1: exist
#  desc: To see if the gid exists
########################################################################
sub exist_gid {
	my $gid = @_[0];
	my $exist = 0;
	$tmpfile = gen_random_filename("");
	my $querySQL = "select gid from LO_GROUP where gid = '$gid';";
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		#naslog($LOG_ACC_NASGROUP,$LOG_WARNING,"49","Check group exist from internal server fail");
		unlink($tmpfile);
		return 0;
	}
	open(my $IN, "<$tmpfile");
	while (<$IN>) {
		if (/(\d+)/) {
			$exist = 1;
		}
		last;
	}
	close($IN);
	unlink($tmpfile);
	return $exist;
}

########################################################################
#  input: [$gid] string
#  output: [$grpName] Return user name or empty string
#  desc: To see if the gid exists
########################################################################
sub get_grpName_by_gid {
	my $gid = @_[0];
	my $grpName = "";
	$tmpfile = gen_random_filename("");
	my $querySQL = "select grpName from LO_GROUP where gid=$gid;";
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		#naslog($LOG_ACC_NASGROUP,$LOG_WARNING,"41","Get group name fail");
		unlink($tmpfile);
		return 0;
	}
	open(my $IN, "<$tmpfile");
	while (<$IN>) {
		$grpName = $_;
		chomp $grpName;
		last;
	}
	close($IN);
	unlink($tmpfile);
	return $grpName;
}
########################################################################
#  input: [$grpName] string
#  output: [$gid] Return group id or empty string
#  desc: To see if the grpName exists
########################################################################
sub get_grpID_by_grpName {
	my $grpName = @_[0];
	my $gid = 0;
	$tmpfile = gen_random_filename("");
	my $querySQL = "select gid from LO_GROUP where grpName=$grpName;";
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		unlink($tmpfile);
		return 0;
	}
	open(my $IN, "<$tmpfile");
	while (<$IN>) {
		$gid = $_;
		chomp $gid;
		last;
	}
	close($IN);
	unlink($tmpfile);
	return $gid;
}
########################################################################
#  input: [$grpName] string
#  output: [$exist] 0: absence 1: exist
#  desc: To see if the group name exists
########################################################################
sub exist_grpName {
	my $grpName = @_[0];
	my $exist = 0;
	$tmpfile = gen_random_filename("");
	my $querySQL = "select gid from LO_GROUP where grpName = '$grpName';";
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		unlink($tmpfile);
		return 0;
	}
	open(my $IN, "<$tmpfile");
	while (<$IN>) {
		if (/(\d+)/) {
			$exist = 1;
		}
		last;
	}
	close($IN);
	unlink($tmpfile);
	return $exist;
}

########################################################################
#  input: [$class]: 'g' or 'u'
#  output: min id according class
#  desc: 
########################################################################
sub get_minid_from_usedpool {
	my $class = @_[0];
	my $minid = -1;
	my $tmpfile = gen_random_filename("");
	my $querySQL = "select min(usedid) from LO_USEDID_POOL where class = '$class';";
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		unlink($tmpfile);
		return 0;
	}
	open(my $IN, "<$tmpfile");
	while (<$IN>) {
		if (/(\d+)/) {
			$minid = $1;
		}
		last;
	}
	close($IN);
	unlink($tmpfile);
	return $minid;
}

########################################################################
#  input: -
#  output: -
#  desc: backup /etc/passwd & /etc/shadow to data area, and also sync to remote
########################################################################
sub bk_user_conf {
	# backup /etc/passwd to data area
	print "Backup and sync user files\n";
	my $ret = system("$CP_CMD -f $CONF_PASSWD $DATA_PATH$CONF_PASSWD");
	if ($ret > 0) {
		naslog($LOG_ACC_NASUSER,$LOG_ERROR,"13","Backup user password file fail.");
	}
	# backup /etc/shadow to data area
	$ret = system("$CP_CMD -f $CONF_SHADOW $DATA_PATH$CONF_SHADOW");
	if ($ret > 0) {
		naslog($LOG_ACC_NASUSER,$LOG_ERROR,"14","Backup user internal system file fail.");
	}
}

########################################################################
#  input: -
#  output: -
#  desc: backup /etc/group & /etc/gshadow to data area, and also sync to remote
########################################################################
sub bk_group_conf {
	print "Backup and sync group files\n";
	# backup /etc/group to data area
	$ret = system("$CP_CMD -f $CONF_GROUP $DATA_PATH$CONF_GROUP");
	if ($ret > 0) {
		naslog($LOG_ACC_NASGROUP,$LOG_ERROR,"21","Backup group internal file fail.");
	}
	# backup /etc/gshadow to data area
	$ret = system("$CP_CMD -f $CONF_GSHADOW $DATA_PATH$CONF_GSHADOW");
	if ($ret > 0) {
		naslog($LOG_ACC_NASGROUP,$LOG_ERROR,"22","Backup group internal file fail.");
	}
}
########################################################################
#  input: $search
#  output: [$count]
#  desc: get count of total AD group in database.
########################################################################
sub get_adsgroups_count {
	my $search = @_[0];
	my $count = 0;
	my $likeSQL = "";
	if (defined($search) && $search ne "") {
		$likeSQL = "where name like '$search%'";
	}

	my $querySQL = "select count(0) from AD_GROUP $likeSQL;";
	$count = exec_acc_sqlcount($querySQL);

	return $count;
}
########################################################################
#  input: $search
#  output: [$count]
#  desc: get count of total AD users in database.
########################################################################
sub get_adsusers_count {
	my $search = @_[0];
	my $count = 0;
	my $likeSQL = "";
	if (defined($search) && $search ne "") {
		$likeSQL = "where name like '$search%'";
	}

	my $querySQL = "select count(0) from AD_USER $likeSQL;";
	$count = exec_acc_sqlcount($querySQL);

	return $count;
}
########################################################################
#  input: [$uid] string
#  output: [$userName] Return user name or empty string
#  desc: get AD user name by uid
########################################################################
sub get_ADuserName_by_uid {
    my $uid = $_[0];
    my $userName = "";
    my $tmpfile = gen_random_filename("");
    my $querySQL = "select name from AD_USER where uid='$uid';";
    my $dbres = exec_acc_sqlcmd($querySQL,$tmpfile);
    if ($dbres != 0) {
        naslog($LOG_FS_QUOTA,$LOG_WARNING,"17","Get user name fail");
        unlink($tmpfile);
        return 0;
    }
    open(my $IN, $tmpfile);
    while (<$IN>) {
        $userName = $_;
        chomp $userName;
        last;
    }
    close($IN);
    unlink($tmpfile);
    return $userName;
}
########################################################################
#  input: [$uname] string
#  output: [$uid] Return user id or empty string
#  desc: get AD user id by uname
########################################################################
sub get_ADuserid_by_userName {
    my $uname = $_[0];
    my $uid = 0;
    my $tmpfile = gen_random_filename("");
    my $querySQL = "select uid from AD_USER where name='$uname';";
    my $dbres = exec_acc_sqlcmd($querySQL,$tmpfile);
    if ($dbres != 0) {
        unlink($tmpfile);
        return 0;
    }
    open(my $IN, $tmpfile);
    while (<$IN>) {
        $uid = $_;
        chomp $uid;
        last;
    }
    close($IN);
    unlink($tmpfile);
    return $uid;
}
########################################################################
#  input: [$gid] string
#  output: [$grpName] Return group name or empty string
#  desc: get AD group name by gid
########################################################################
sub get_ADgrpName_by_gid {
    my $gid = $_[0];
    my $grpName = "";
    my $tmpfile = gen_random_filename("");
    my $querySQL = "select name from AD_GROUP where gid='$gid';";
    my $dbres = exec_acc_sqlcmd($querySQL,$tmpfile);
    if ($dbres != 0) {
        naslog($LOG_FS_QUOTA,$LOG_WARNING,"18","Get group name fail");
        unlink($tmpfile);
        return 0;
    }
    open(my $IN, $tmpfile);
    while (<$IN>) {
        $grpName = $_;
		chomp $grpName;
        last;
    }
    close($IN);
    unlink($tmpfile);
    return $grpName;
}
########################################################################
#  input: [$grpName] string
#  output: [$gid] Return group id or empty string
#  desc: get AD group id by grpName
########################################################################
sub get_ADgrpid_by_grpName {
    my $grpName = $_[0];
    my $gid = 0;
    my $tmpfile = gen_random_filename("");
    my $querySQL = "select gid from AD_GROUP where name='$grpName';";
    my $dbres = exec_acc_sqlcmd($querySQL,$tmpfile);
    if ($dbres != 0) {
        unlink($tmpfile);
        return 0;
    }
    open(my $IN, $tmpfile);
    while (<$IN>) {
        $gid = $_;
		chomp $gid;
        last;
    }
    close($IN);
    unlink($tmpfile);
    return $gid;
}
########################################################################
#  input: $search
#  output: [$count]
#  desc: get count of total domain group in database.
########################################################################
sub get_domain_groups_count {
	my $search = @_[0];
	my $count = 0;
	my $likeSQL = "";
	if (defined($search) && $search ne "") {
		$likeSQL = "where name like '$search%'";
	}

	my $querySQL = "select count(0) from AD_GROUP $likeSQL;";
	$count = exec_acc_sqlcount($querySQL);

	return $count;
}
########################################################################
#  input: $search
#  output: [$count]
#  desc: get count of total domain  users in database.
########################################################################
sub get_domain_users_count {
	my $search = @_[0];
	my $count = 0;
	my $likeSQL = "";
	if (defined($search) && $search ne "") {
		$likeSQL = "where name like '$search%'";
	}

	my $querySQL = "select count(0) from AD_USER $likeSQL;";
	$count = exec_acc_sqlcount($querySQL);

	return $count;
}
########################################################################
#  input: -
#  output: [$MAX_UID]
#  desc: get limit id of user
########################################################################
sub get_maxlimit_user_id {
	my %limits = get_limits();
	my $max_user_count = $limits{"max_user_count"};
	my $MAX_UID = $MIN_UID + $max_user_count -1;
	return $MAX_UID;
}
########################################################################
#  input: -
#  output: [$MAX_GID]
#  desc: get limit id of group
########################################################################
sub get_maxlimit_group_id {
	my %limits = get_limits();
	my $max_group_count = $limits{"max_group_count"};
	my $MAX_GID = $MIN_GID + $max_group_count -1;
	return $MAX_GID;
}
########################################################################
#  input: -
#  output: [$max_user_count]
#  desc: get limit count of user
########################################################################
sub get_maxlimit_user_count {
	my %limits = get_limits();
	my $max_user_count = $limits{"max_user_count"};

	return $max_user_count;
}
########################################################################
#  input: -
#  output: [$max_group_count]
#  desc: get limit count of group
########################################################################
sub get_maxlimit_group_count {
	my %limits = get_limits();
	my $max_group_count = $limits{"max_group_count"};

	return $max_group_count;
}

return 1;  # this is required.
