###################################################################
#  (C) Copyright Promise Technology Inc., 2013 All Rights Reserved
#  Name: lib/qt_lib.pl
#  Author: Kylin
#  Modifier:
#  Date: 2013/02/06
#  Description: Common functions for quota.
###################################################################

require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/dir_path.pl";
require "/nasapp/perl/lib/acc_db_lib.pl";
require "/nasapp/perl/lib/fs_lib.pl";
require "/nasapp/perl/lib/fs_db_lib.pl";

########################################################################
#  input: $token, $sdName, $source, $savefile
#  output: $res 0=OK, other=fail
#  desc: Overwrite data from $savefile to QUOTA_UNSET table
########################################################################
sub save_quota_unset {
	my ($token, $sdName, $source, $savefile)= @_;

	my $sqlfile = gen_random_filename("");
	open(my $OUT, ">$sqlfile");
	print $OUT "BEGIN TRANSACTION;\n";
	open(my $IN, $savefile);
	while (<$IN>) {
		if (/(\d+),(\d+)/) {
			my $id = $1;
			my $limited = $2;
			print $OUT "update QUOTA_UNSET set limitSet = $2 where token = '$token' and sdName = '$sdName' and source = $source and id = $id;\n";
		}
	}
	print $OUT "COMMIT;\n";
	close($IN);
	close($OUT);

	# execute SQL command
	$dbres = exec_acc_sqlfile($sqlfile);
	if ($dbres != 0) {
		naslog($LOG_FS_QUOTA,$LOG_ERROR,"10","Update [$id] quota setting to [$sdName] fail!.");
	}
	unlink($savefile);

	return $dbres;
}

########################################################################
#  input: $token(must), $sdName(must), $source(must), $search(optional)
#  output: [$count] 0~N= $count
#  desc: get count of quota in table QUOTA_UNSET by sdName and source.
########################################################################
sub get_quota_unset_count {
	my ($token, $sdName, $source, $search)= @_;
	my $count = 0;

	my $countSQL = "select count(0) from QUOTA_UNSET where token = '$token' and sdName = '$sdName' and source = $source";
	if (defined($search) && $search ne "") {
		$countSQL .= " and name like '$search%'";
	}
	$countSQL .= ";";
	
	$count = exec_acc_sqlcount($countSQL);

	return $count;
}

########################################################################
#  input: $sdName(must), $source(must), $search(optional)
#  output: [$count] 0~N= $count
#  desc: get count of quota in table QUOTA_UNSET by sdName and source.
########################################################################
sub get_quota_count {
	my ($sdName, $source, $search)= @_;
	my $count = 0;

	my $countSQL = "select count(0) from QUOTA where sdName = '$sdName' and source = $source";
	if (defined($search) && $search ne "") {
		$countSQL .= " and name like '$search%'";
	}
	$countSQL .= ";";
	
	$count = exec_acc_sqlcount($countSQL);

	return $count;
}

########################################################################
#  input: $mount(must)
#  output: -
#  desc: set system quota information into DB table.
########################################################################
sub refresh_quotainfo2_db {
    my $mount = @_[0];
    my ($uname,$lvalue,$uvalue,$gname)=("",0,0,"");
    my $uid=0;
    my $gid=0;
    my $dbres=0;

    #naslog($LOG_FS_QUOTA,$LOG_INFORMATION,"26","Init [$mount] quota info.");
    print "Init [$mount] quota info.\n";
    system("$GFS2QUOTA_CMD init -f $mount");
    
    #get quota report forms
    #naslog($LOG_FS_QUOTA,$LOG_INFORMATION,"27","Get [$mount] quota info.");
    print "Get [$mount] quota info.\n";
    my $command = "$GFS2QUOTA_CMD list -f $mount"; 

    my @shareDiskInfo = get_share_disk_info();
    my %mounted_sd = ();
    for (my $i=0; $i<=$#shareDiskInfo; $i++) {
        if ($shareDiskInfo[$i]{'mounted'} == 1) {
            $mounted_sd{$shareDiskInfo[$i]{'mount_on'}} = $shareDiskInfo[$i]{'sdname'};
        }
    }

    my %setting = get_domain_setting();
    my $netbiosname = $setting{"netbios"};

    open(my $QIN,"$command |");
    while(<$QIN>){
        #gfs2 quota information from the gfs2_quota command is displayed as follows:
        #=========================================================
        #user    testuser:  limit: 5.0        warn: 0.0        value: 0.0
        #user       test1:  limit: 50.0       warn: 0.0        value: 0.0
        #group      test2:  limit: 50.0       warn: 0.0        value: 0.0
        #group      test1:  limit: 30.0       warn: 0.0        value: 0.0
        if(/^user\s+(\S+)\:\s+(limit)\:\s+(\d+\.\d+)\s+(warn)\:\s+(\d+\.\d+)\s+(value)\:\s+(\d+\.\d+)/){
            my $uname = $1;
            my $source = 0;
            my $uid = 0;
            if($uname eq "root"){#root
                print "This is root\n";
                next;
            }

            my $lvalue = $3/1024; #total(limit) GB
            my $uvalue = $7/1024; #used(value) GB

            my $check_exist = 0;
            open(my $FIN, "$ID_CMD \"$uname\" |");
            while (<$FIN>){
                if (/^uid=(\d+)/) {
                    if($1 < 1000){
                        next;
                    }
                    else{
                        $check_exist = 1;
                        last;
                    }
                }
            }
            close($FIN);

            #print "check_exist:$check_exist\n";
            if($check_exist){
                $source=1;
                $uid = get_userID_by_userName($uname);
                if($uid == 0){
                    next;
                }
            }
            else{
                $source=3;
                $uid = get_ADuserid_by_userName($uname);
                if($uid == 0){
                    next;
                }
            }

            #change $sdName to $mount_sdName
            if (!exists($mounted_sd{$mount})) {
                next ;
            }
            else{
                $sdName = $mounted_sd{$mount};
            }

            my $checkSQL = "select * from QUOTA where sdName = '$sdName' and source = $source and name = '$uname'";
            $chkret = exec_acc_sqlcmd($checkSQL);
            if($chkret != 0){
                next ;
            }
	    
            # generate SQL
            #naslog($LOG_FS_QUOTA,$LOG_INFORMATION,"11","Set [$uname] quota limit [$lvalue] to [$sdName].");
            my $insertSQL = "update QUOTA set valueGet = $uvalue where sdName = '$sdName' and source = $source and name = '$uname';\n";

            # execute SQL command
            $dbres = exec_acc_sqlcmd($insertSQL);
            if ($dbres != 0) {
                #naslog($LOG_FS_QUOTA,$LOG_ERROR,"20","upda user [$uname] quota limit [$lvalue] to [$sdName] error.");
                next ;
            }
        }
        elsif(/^group\s+(\S+)\:\s+(limit)\:\s+(\d+\.\d+)\s+(warn)\:\s+(\d+\.\d+)\s+(value)\:\s+(\d+\.\d+)/){
            my $gname = $1;
            my $source = 0;
            my $gid = 0;
            if($gname eq "root"){#root
                print "This is root\n";
                next;
            }

            $lvalue = $3/1024; #total(limit) GB
            $uvalue = $7/1024; #used(value) GB

            my $check_exist = 0;
            open(my $GIN,"$GREP_CMD \"$gname\" $CONF_GROUP |");
            while (<$GIN>){
                if (/(\S+)\:x\:(\d+)/) {
                    if($2 < 1000){
                        next;
                    }
                    else{
                        $check_exist = 1;
                        last;
                    }
                }
            }
            close($GIN);

            if($check_exist){
                $source=2;
                $gid = get_grpID_by_grpName($gname);
                if($gid == 0){
                    next;
                }
            }
            else{
                $source=4;
                $gid = get_ADgrpid_by_grpName($gname);
                if($gid == 0){
                    next;
                }
            }

           #change $sdName to $mount_sdName
            if (!exists($mounted_sd{$mount})) {
                next ;
            }
            else{
                $sdName = $mounted_sd{$mount};
            }

            my $checkSQL = "select * from QUOTA where sdName = '$sdName' and source = $source and name = '$gname'";
            $chkret = exec_acc_sqlcmd($checkSQL);
            if($chkret != 0){
                next ;
            }
	    
            # generate SQL
            #naslog($LOG_FS_QUOTA,$LOG_INFORMATION,"11","Set [$gname] quota limit [$lvalue] to [$sdName].");
            my $insertSQL = "update QUOTA set valueGet = $uvalue where sdName = '$sdName' and source = $source and name = '$gname';\n";

            # execute SQL command
            $dbres = exec_acc_sqlcmd($insertSQL);
            if ($dbres != 0) {
                next ;
            }
        }
    }
    close($QIN);

    return 0;
}

########################################################################
#  input: $source, $id
#  output: $res 0=OK, other=fail
#  desc: clear one user or one group quota limitation
########################################################################
sub clear_id_quota {
	my ($source, $id)= @_;
	print "S:$source \ ID:$id\n";

	#select all sdname which set $uid quota limit
	my $tmpfile = gen_random_filename("");
	my $selSQL = "select DISTINCT sdName from QUOTA where source = $source and id = $id;";
	my $dbres = exec_acc_sqlcmd($selSQL,$tmpfile);
	if ($dbres != 0) {
		naslog($LOG_FS_QUOTA,$LOG_ERROR,"30","Get [$name] quota info fail.");
		unlink($tmpfile);
		return 0;
	}
	open(my $QIN, $tmpfile);
	my @shareDiskInfo = get_share_disk_info();
	my %mounted_sd = ();
	for (my $i=0; $i<=$#shareDiskInfo; $i++) {
		if ($shareDiskInfo[$i]{'mounted'} == 1) {
			$mounted_sd{$shareDiskInfo[$i]{'sdname'}} = $shareDiskInfo[$i]{'mount_on'};
		}
	}

	while(<$QIN>) {
		chomp $_;
		my $sd=$_;
		if($sd ne ""){
			if (exists($mounted_sd{$sdName})) {
				$mount_sdName=$mounted_sd{$sdName};
			}
			else{
				naslog($LOG_FS_QUOTA,$LOG_ERROR,"01","Share disk [$sd] is not existed.");
				return 0;
			}

			naslog($LOG_FS_QUOTA,$LOG_INFORMATION,"02","clear [$source] ID[$id] mount[$mount_sdName] Quota.");
			if($source == 1){
				system("$GFS2QUOTA_CMD limit -u \"$id\" -l 0 -f \"$mount_sdName\"");
			}
			elsif($source == 2){
				system("$GFS2QUOTA_CMD limit -g \"$id\" -l 0 -f \"$mount_sdName\"");
			}
		}
	}
	close($QIN);
	unlink($tmpfile);

	return 0;
}

return 1;  # this is required.