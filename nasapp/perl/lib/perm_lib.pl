#!/usr/bin/perl
#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: perm_lib.pl
#  Author: Paul Chang
#  Date: 2013/01/24
#  Description:
#    Functions about processing Share Disk database.
#########################################################################

require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/acc_db_lib.pl";
require "/nasapp/perl/lib/fs_lib.pl";
require "/nasapp/perl/lib/pro_lib.pl";
require "/nasapp/perl/lib/db_lib.pl";
require "/nasapp/perl/lib/log_db_lib.pl";

########################################################################
#  input: $sdname, $source, $search
#  output: [$count]
#  desc: get count of total permissions of input Share Disk in database.
########################################################################
sub get_sd_permission_count {
	my ($sdname, $source, $search) = @_;
	my $count = 0;

	if ($source < 1 || $source > 4) {
		print "Invalid source format\n";
		return -2;
	}
	
	my $likeSQL = "";
	if (defined($search) && $search ne "") {
		$likeSQL = "and name like '%$search%'";
	}
	
	my $querySQL = "select count(0) from PERMISSION where sdName = '$sdname' and source = $source $likeSQL;";
	$count = exec_acc_sqlcount($querySQL);

	return $count;
}

########################################################################
#  input: $sdname, $source, $token, $search
#  output: [$count]
#  desc: get count of unset permissions of input Share Disk and source in database.
########################################################################
sub get_sd_unset_permission_count {
	my ($sdname, $source, $token, $search) = @_;
	my $count = 0;
	
	if ($source < 1 || $source > 4) {
		print "Invalid source format\n";
		return -2;
	}
	
	my $likeSQL = "";
	if (defined($search) && $search ne "") {
		$likeSQL = "and PERM_UNSET.name like '%$search%'";
	}
	if($source == 4) {
		my $filterSQL = get_group_filter_sql("PERM_UNSET", "id");#Minging.Tsai. 2014/10/8.
		my $querySQL = "select count(0) from PERM_UNSET where sdName = '$sdname' and source = $source and token = '$token' $filterSQL $likeSQL;";
		$count = exec_acc_sqlcount($querySQL);
	} elsif($source == 3) {
		my $filterSQL = get_group_filter_sql("AD_USER", "gid_string");#Minging.Tsai. 2014/10/8.
		my $querySQL = "select count(0) from PERM_UNSET join AD_USER where PERM_UNSET.sdName = '$sdname' and PERM_UNSET.token = '$token' and PERM_UNSET.id=AD_USER.uid $filterSQL $likeSQL;";
		$count = exec_acc_sqlcount($querySQL);
	}
	return $count;
}

########################################################################
#  input: $permListFile, $sdname, $source, $token
#  output: 0=OK, others=failed with error code
#  desc: set permission list to PERM_UNSET table
########################################################################
sub set_sd_unset_permissions {
	my ($permListFile, $sdname, $source, $token) = @_;
	
	my $sqlfile = gen_random_filename("");
	open(my $OUT, ">$sqlfile");
	print $OUT "BEGIN TRANSACTION;\n";
	open(my $IN, "<$permListFile");
	my $insertSQL = "";
	while (<$IN>) {
		if (/(\d+),(\d+)/) {
			my $id = $1;
			my $perm = $2;
			print $OUT "update PERM_UNSET set perm = $perm where token = '$token' and sdName = '$sdname' and source = $source and id = $id;\n";
		}
	}
	print $OUT "COMMIT;\n";
	close($IN);
	close($OUT);

	# execute SQL command
	my $dbres = exec_acc_sqlfile($sqlfile);
	unlink($permListFile);
	
	return $dbres;
}
########################################################################
#  output: $filterSQL 
#  desc: get SQL string according to /nasdata/config/etc/group_filter.conf.
########################################################################
#Minging.Tsai. 2014/10/7.
sub get_group_filter_sql {
	my ($table, $item) = @_;
	my $group_filter = "";
	$group_filter = `cat /nasdata/config/etc/group_filter.conf`;
	my @group_ary = split(/,/, $group_filter);
	my $filterSQL = "";#"and (AD_GROUP.id = '1' or AD_GROUP.id = '2')";
	foreach $group (@group_ary) {
		if($group =~ /(\d+)/) {
			my $gid = "";
			my $oper = "\=";
			if($table ne "AD_USER") {
				$gid = $1;
			} else {
				$gid = "\%\," . $1 ."\,\%";
				$oper = "LIKE";
			}
			if($filterSQL eq "") {
				$filterSQL .= "and ($table\.$item $oper \'". $gid . "\'";
			} else {
				$filterSQL .= " or $table\.$item $oper \'". $gid . "\'";
			}
		}
	}
	$filterSQL = $filterSQL . ")" if($filterSQL ne "");
	print "filterSQL=$filterSQL\n";
	return $filterSQL;
}
########################################################################
#  input: $sdname, $source, $token, $page, $pageSize, $search, $sort, $direct, $outfile
#  output: 0=OK, others=failed with error code
#  desc: get permission list and dump to outfile
########################################################################
sub get_sd_unset_permission {
	my ($sdname, $source, $token, $page, $pageSize, $search, $sort, $direct, $outfile) = @_;
	
	my $likeSQL = "";
	if ($search ne "") {
		$likeSQL = "and PERM_UNSET.name like '%$search%'";
	}
	my $start = ($page - 1) * $pageSize;
	if ($sort eq "checked") {
		$sort = "checked desc, name asc";
		$direct = "";
	}


	my $querySQL = "";
	if($source == 3){
		my $filterSQL = get_group_filter_sql("AD_USER", "gid_string");
#$querySQL = "select PERM_UNSET.id as id, PERM_UNSET.name as name, PERM_UNSET.perm as perm , (case when PERM_UNSET.perm is 0 then 0 else 1 end) as checked, AD_USER.gname as gname,(case when PERMISSION.perm is NULL then 0 else PERMISSION.perm end) as gperm from PERM_UNSET,AD_USER LEFT JOIN PERMISSION on AD_USER.gid=PERMISSION.id and PERMISSION.source=4 and PERMISSION.sdName = '$sdname' where PERM_UNSET.sdName = '$sdname' and PERM_UNSET.source = 3 and PERM_UNSET.token = '$token' and AD_USER.uid=PERM_UNSET.id $filterSQL $likeSQL order by $sort $direct limit $start, $pageSize;"
		$querySQL = "select PERM_UNSET.id as id, PERM_UNSET.name as name, PERM_UNSET.perm as perm , (case when PERM_UNSET.perm is 0 then 0 else 1 end) as checked, 'gn' as gname, '3057' as gperm from PERM_UNSET,AD_USER where PERM_UNSET.sdName = '$sdname' and PERM_UNSET.source = 3 and PERM_UNSET.token = '$token' and AD_USER.uid=PERM_UNSET.id $filterSQL $likeSQL order by $sort $direct limit $start, $pageSize;"
	}else{
		my $filterSQL = get_group_filter_sql("PERM_UNSET", "id");
		$querySQL = "select id, name, perm, (case when perm is 0 then 0 else 1 end) as checked from PERM_UNSET where sdName = '$sdname' and source = $source and token = '$token' $filterSQL $likeSQL order by $sort $direct limit $start, $pageSize;";
	}
	print "querySQL = $querySQL\n";
	my $sqlfile = gen_random_filename("");
	open(my $OUT, ">$sqlfile");
	print $OUT ".header on\n";
	print $OUT ".separator \"\x4 | \x4\"\n";
	print $OUT "$querySQL\n";
	close($OUT);
	
	# execute query SQL command, dump to $outfile directly
	$dbres = exec_acc_sqlfile($sqlfile, $outfile);	
	patch_multi_gperm($outfile, $sdname) if($source eq "3");

	return $dbres;
}
#Minging.Tsai. 2014/11/19. Add the additional multi-gperm column 
sub patch_multi_gperm {
	my ($outfile, $sdname) = @_;
	my @cont = ();
	open(my $IN, "$outfile");
	@cont = <$IN>;
	close($IN);
	my %gperm_hash = ();#cache the searched group perm.
	my %gname_hash = ();#cache the searched group name string.
	open(my $IN_PERM, "sqlite3_v2 /nasdata/config/etc/user.db \"select name, perm, source, sdName from PERMISSION\" |");
	while(<$IN_PERM>) {
		if(/(.*?)\|([0-3])\|4\|\Q$sdname\E/) {
			$gname = $1;
			$gperm = $2;
			$gperm_hash{$gname} = $gperm;
		}
	}
	close($IN_PERM);
    open(my $IN_UNSET, "sqlite3_v2 /nasdata/config/etc/user.db \"select name, perm, source, sdName from PERM_UNSET\" |");
    while(<$IN_UNSET>) {
		if(/(.*?)\|([0-3])\|4\|\Q$sdname\E/) {
            $gname = $1;
			$gperm = $2;
            $gperm_hash{$gname} = $gperm;
		}
	}
	close($IN_UNSET);

    open(my $IN_USER, "sqlite3_v2 /nasdata/config/etc/user.db \"select name, gname from AD_USER\" |");
    while(<$IN_USER>) {
        if(/(.*?)\|(.+)/) {
            $uname = $1;
            $gname = $2;
            $gname_hash{$uname} = $gname;
		}
	}
	close($IN_USER);

	foreach $line (@cont) {
		#id | name | perm | checked | gname | gperm
		#1 | testuser1 | 0 | 0 | gn | 3057
		if($line =~ /^\d+\x4\s\|\s\x4(.*?)\x4\s\|\s\x4.+\x4\s\|\s\x4\d+/) {
			my $uname = $1;		
			my $gname_str = $gname_hash{$uname};
			my $gname_str_sorted = "";
			my @gname_ary = split(/\,/, $gname_str);
			my $gperm_str = "";
			my $count = 0;
			my @rw_grp = ();
			my @ro_grp = ();
			my @unset_grp = ();
			#Minging.Tsai. 2014/12/16. Now gname and gperm only return the 20 groups with highest permission
			foreach $gname_ary_item (@gname_ary) {
				next if($gname_ary_item eq "");
				$gperm_hash{$gname_ary_item} = 0 if($gperm_hash{$gname_ary_item} eq "");
				if($gperm_hash{$gname_ary_item} == 1) {#deny group can output directly.
					$gperm_str .= "1,";
					$gname_str_sorted .= $gname_ary_item . ",";
					$count++;
				} elsif($gperm_hash{$gname_ary_item} == 3) {
					push @rw_grp, "$gname_ary_item";
				} elsif($gperm_hash{$gname_ary_item} == 2) {
					push @ro_grp, "$gname_ary_item";
				} elsif($gperm_hash{$gname_ary_item} == 0) {
					push @unset_grp, "$gname_ary_item";
				}
				last if($count >= 20);
			}
			#rw -> ro -> unset to collect 20 data if necessary.
			foreach $rw_grp_item (@rw_grp) {
				last if($count >= 20);
	            $gperm_str .= "3,";
	            $gname_str_sorted .= $rw_grp_item . ",";
	            $count++;
			}
			foreach $ro_grp_item (@ro_grp) {
				last if($count >= 20);
				$gperm_str .= "2,";
				$gname_str_sorted .= $ro_grp_item . ",";
				$count++;
			}
			foreach $unset_grp_item (@unset_grp) {
				last if($count >= 20);
				$gperm_str .= "0,";
				$gname_str_sorted .= $unset_grp_item . ",";
				$count++;
			}
			if($gperm_str eq "") {
				$gperm_str = "0";
			} else {
				$gperm_str = "," . $gperm_str;
			}
			$gname_str_sorted = "," . $gname_str_sorted if($gname_str_sorted ne "");
			$line =~ s/^(.+)gn(\x4\s\|\s\x4)\d+/$1$gname_str_sorted$2$gperm_str/;
		}	
	}
	open(my $OUT, ">$outfile");
	print $OUT @cont;
	close($OUT);
}

########################################################################
#  input: $sdname, $source
#  output: 0=OK, others=failed with error code
#  desc: delete set permission of input Share Disk.
########################################################################
sub del_sd_set_permissions {
	my ($sdname, $source) = @_;
	chomp($sdname);
	my $sqlfile;
	my $dbres;
	
	my $deleteSQL = "delete from PERMISSION where sdName = '$sdname'";
	if (defined($source)) {
		$deleteSQL .= " and source = $source;";
	}
		 
	# execute SQL command
	$dbres = exec_acc_sqlcmd($deleteSQL);
	if ($dbres != 0) {
		print "exec: $deleteSQL error\n";
	}
	return $dbres;
}

########################################################################
#  input: $token
#  output: 0=OK, others=failed with error code
#  desc: delete unset permission by token.
########################################################################
sub del_sd_unset_permissions {
	my ($token) = @_;
	chomp($token);
	my $dbres;
	
	my $deleteSQL = "delete from PERM_UNSET where token = '$token';";
	# execute SQL command
	$dbres = exec_acc_sqlcmd($deleteSQL);
	if ($dbres != 0) {
		print "exec: $deleteSQL error\n";
	}
	return $dbres;
}

########################################################################
#  input: -
#  output: 0=OK, others=failed with error code
#  desc: delete domain user and group in PERMISSION table.
########################################################################
sub del_domain_permissions {
	my $deleteSQL = "delete from PERMISSION where (source = 3 or source = 4);";
	my $dbres = exec_acc_sqlcmd($deleteSQL);
	if ($dbres != 0) {
		print "exec: $deleteSQL error\n";
	}
	return $dbres;
}
########################################################################
#  input: - 
#  output: 0=OK, others=failed with error code
#  desc: delete domain user and group which is not in selected greoups in PERMISSION table.
########################################################################
sub del_filtered_permissions {
	my (@group_ary) = @_;
	my $id_string = "";#"\(id != '1' and id != '2'\)";
	my $gid_string = "";#"\(gid != '1' and gid != '2'\)";
	foreach $group (@group_ary) {
		if($group =~ /(\d+)/) {
			if($id_string eq "") {
				$gid_string .= "gid_string NOT LIKE \'\%\," . $1 . "\,\%'";
				$id_string .= "id != \'" . $1 . "'";
			} else {
				$gid_string .= "and gid_string NOT LIKE \'\%\," . $1 . "\,\%'";
				$id_string .= " and id != \'" . $1 . "'";			
			}
		}
	}
	print "id_string=$id_string\n";
	print "gid_string=$gid_string\n";
	my $deleteSQL = "delete from PERMISSION where ((id in (Select uid from AD_USER Where $gid_string) and source = '3') or ($id_string and source = '4'));";
	print "$deleteSQL\n";
	my $dbres = exec_acc_sqlcmd($deleteSQL);
	if ($dbres != 0) {
		print "exec: $deleteSQL error\n";
	}
	return $dbres;
}


########################################################################
#  input: $sdname
#  output: array of deny users
#  desc: get deny users of input Share Disk in database, include local and domain user.
########################################################################
sub get_sd_deny_users {
	my ($sdname) = @_;
	my @deny_user = ();
	
	my $querySQL = "select name from PERMISSION where sdName = '$sdname' and (source = 1 or source = 3) and perm = 1;";
	my $tmpfile = gen_random_filename("");
	# execute SQL command
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		print "exec: $querySQL error\n";
		unlink($tmpfile);
		naslog($LOG_ACC_PERMISSION, $LOG_ERROR, "26", "Get deny users of Share Disk \"$sdname\" error:$dbres.");
		return @deny_user;
	}
	
	open(my $IN, $tmpfile);
	while(<$IN>) {
		chomp $_;
		push @deny_user, "$_";
	}
	close($IN);
	unlink($tmpfile);
		
	return @deny_user;
}

########################################################################
#  input: $sdname
#  output: array of deny groups
#  desc: get deny groups of input Share Disk in database, include local and domain group.
########################################################################
sub get_sd_deny_groups {
	my ($sdname) = @_;
	my @deny_group = ();
	
	my $querySQL = "select name from PERMISSION where sdName = '$sdname' and (source = 2 or source = 4) and perm = 1;";
	my $tmpfile = gen_random_filename("");
	# execute SQL command
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		print "exec: $querySQL error\n";
		unlink($tmpfile);
		naslog($LOG_ACC_PERMISSION, $LOG_ERROR, "27", "Get deny groups of Share Disk \"$sdname\" error:$dbres.");
		return @deny_group;
	}
	
	open(my $IN, $tmpfile);
	while(<$IN>) {
		chomp $_;
		push @deny_group, "$_";
	}
	close($IN);
	unlink($tmpfile);
	
	return @deny_group;
}

########################################################################
#  input: $sdname
#  output: array of read only users
#  desc: get read only users of input Share Disk in database, include local and domain user.
########################################################################
sub get_sd_ro_users {
	my ($sdname) = @_;
	my @ro_user = ();
	
	my $querySQL = "select name from PERMISSION where sdName = '$sdname' and (source = 1 or source = 3) and perm = 2;";
	my $tmpfile = gen_random_filename("");
	# execute SQL command
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		print "exec: $querySQL error\n";
		unlink($tmpfile);
		naslog($LOG_ACC_PERMISSION, $LOG_ERROR, "28", "Get read-only users of Share Disk \"$sdname\" error:$dbres.");
		return @ro_user;
	}
	
	open(my $IN, $tmpfile);
	while(<$IN>) {
		chomp $_;
		push @ro_user, "$_";
	}
	close($IN);
	unlink($tmpfile);
		
	return @ro_user;
}

########################################################################
#  input: $sdname
#  output: array of read only groups
#  desc: get read only groups of input Share Disk in database, include local and domain group.
########################################################################
sub get_sd_ro_groups {
	my ($sdname) = @_;
	my @ro_group = ();
	
	my $querySQL = "select name from PERMISSION where sdName = '$sdname' and (source = 2 or source = 4) and perm = 2;";
	my $tmpfile = gen_random_filename("");
	# execute SQL command
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		print "exec: $querySQL error\n";
		unlink($tmpfile);
		naslog($LOG_ACC_PERMISSION, $LOG_ERROR, "29", "Get read-only groups of Share Disk \"$sdname\" error:$dbres.");
		return @ro_group;
	}
	
	open(my $IN, $tmpfile);
	while(<$IN>) {
		chomp $_;
		push @ro_group, "$_";
	}
	close($IN);
	unlink($tmpfile);
		
	return @ro_group;
}

########################################################################
#  input: $sdname
#  output: array of read/write users
#  desc: get read/write users of input Share Disk in database, include local and domain user.
########################################################################
sub get_sd_rw_users {
	my ($sdname) = @_;
	my @rw_user = ();
	
	my $querySQL = "select name from PERMISSION where sdName = '$sdname' and (source = 1 or source = 3) and perm = 3;";
	my $tmpfile = gen_random_filename("");
	# execute SQL command
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		print "exec: $querySQL error\n";
		unlink($tmpfile);
		naslog($LOG_ACC_PERMISSION, $LOG_ERROR, "30", "Get read-write users of Share Disk \"$sdname\" error:$dbres.");
		return @rw_user;
	}
	
	open(my $IN, $tmpfile);
	while(<$IN>) {
		chomp $_;
		push @rw_user, "$_";
	}
	close($IN);
	unlink($tmpfile);
	
	return @rw_user;
}

########################################################################
#  input: $sdname
#  output: array of read/write groups
#  desc: get read/write groups of input Share Disk in database, include local and domain groups.
########################################################################
sub get_sd_rw_groups {
	my ($sdname) = @_;
	my @rw_group = ();
	
	my $querySQL = "select name from PERMISSION where sdName = '$sdname' and (source = 2 or source = 4) and perm = 3;";
	my $tmpfile = gen_random_filename("");
	# execute SQL command
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
	if ($dbres != 0) {
		print "exec: $querySQL error\n";
		unlink($tmpfile);
		naslog($LOG_ACC_PERMISSION, $LOG_ERROR, "31", "Get read-write groups of Share Disk \"$sdname\" error:$dbres.");
		return @rw_group;
	}
	
	open(my $IN, $tmpfile);
	while(<$IN>) {
		chomp $_;
		push @rw_group, "$_";
	}
	close($IN);
	unlink($tmpfile);
	
	return @rw_group;
}

sub get_sd_unset_ADuser {
	my ($sdname) = @_;
	my @unset_user=();
	my $querySQL = "select name from AD_USER where uid not in (Select id from PERMISSION Where sdName = '$sdname' and source = 3)";
	my $tmpfile = gen_random_filename("");
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
    if ($dbres != 0) {
        print "exec: $querySQL error\n";
        unlink($tmpfile);
        naslog($LOG_ACC_PERMISSION, $LOG_ERROR, "31", "Get unset AD user of Share Disk \"$sdname\" error:$dbres.");
        return @unset_user;
    }
	open(my $IN, $tmpfile);
	while(<$IN>) {
		chomp $_;
		push @unset_user, "$_";
	}
	close($IN);
	unlink($tmpfile);
	return @unset_user;
}

sub get_sd_unset_ADgroup {
	my ($sdname) = @_;
	my @unset_group=();
	my $querySQL = "select name from AD_GROUP where gid not in (Select id from PERMISSION Where sdName = '$sdname' and source = 4)";
	my $tmpfile = gen_random_filename("");
	my $dbres = exec_acc_sqlcmd($querySQL, $tmpfile);
    if ($dbres != 0) {
        print "exec: $querySQL error\n";
        unlink($tmpfile);
        naslog($LOG_ACC_PERMISSION, $LOG_ERROR, "31", "Get unset AD group of Share Disk \"$sdname\" error:$dbres.");
        return @unset_group;
    }
	open(my $IN, $tmpfile);
	while(<$IN>) {
		chomp $_;
		push @unset_group, "$_";
	}
	close($IN);
	unlink($tmpfile);
	return @unset_group;
}


sub GetPermissionid{
	my $timestamp = 0;
	if(! -f "/nasdata/config/etc/permissionId.conf"){
		system("echo \"0\" > /nasdata/config/etc/permissionId.conf");
	}
	open(my $IN,"/nasdata/config/etc/permissionId.conf");
	while(<$IN>){
		if(/(\d+)/){
			$timestamp=$1;
		}
	}
	close($IN);
	return $timestamp;
}

sub SetPermissionid{
	my($timestamp)=@_;
	system("echo \"$timestamp\" > /nasdata/config/etc/permissionId.conf");
	return 0;
}

########################################################################
#  input: $sdname
#  output: array of nfs allow ips
#  desc: get nfs allow ips of input Share Disk in database.
########################################################################
#sub get_sd_allow_ip {
#	my ($sdname) = @_;
#	my @allow_ip = ();
#	
#	my $querySQL = "select allow_ip from NFS_ALLOW_IP where sdname = '$sdname';";
#	my $tmpfile = gen_random_filename("");
#	# execute SQL command
#	my $dbres = exec_fs_sqlcmd($querySQL, $tmpfile);
#	if ($dbres != 0) {
#		print "exec: $querySQL error\n";
#		unlink($tmpfile);
#		naslog($LOG_ACC_PERMISSION, $LOG_ERROR, "32", "Get NFS allow ip of Share Disk \"$sdname\" error:$dbres.");
#		return @allow_ip;
#	}
#	open(my $IN, $tmpfile);
#	while(<$IN>) {
#		chomp $_;
#		push @allow_ip, "$_";
#	}
#	close($IN);
#	unlink($tmpfile);
#	
#	return @allow_ip;
#}

return 1;
