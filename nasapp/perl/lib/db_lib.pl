#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: db_lib.pl
#  Author: Kylin Shih
#  Date: 2013/01/25
#  Description:
#    Definition of database.
#########################################################################

require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/conf_path.pl";

# Max deletion counts one time
$MAX_QUERY_COUNT = 500;

########################################################################
#	input: string
#	output:	 string
#	Desc: function to add another single quote before single quote
########################################################################
sub escape_single_quote {
	my $string = shift;
	$string =~ s/\'/\'\'/g;
	return $string;
}

########################################################################
#  input: $sqlfile, $outfile
#  output: See exec_sqlfile()
#  desc: See exec_sqlfile()
########################################################################
sub exec_acc_sqlfile {
	my ($sqlfile, $outfile) = @_;
	my $res = exec_sqlfile($sqlfile, $outfile, $CONF_DB_USER);
	return $res;
}

########################################################################
#  input: $sqlcmd, $outfile
#  output: See exec_sqlcmd()
#  desc: See exec_sqlcmd()
########################################################################
sub exec_acc_sqlcmd {
	my ($sqlcmd, $outfile) = @_;
	my $res = exec_sqlcmd($sqlcmd, $outfile, $CONF_DB_USER);
	return $res;
}

########################################################################
#  input: $sqlcmd
#  output: See exec_sqlcount()
#  desc: See exec_sqlcount()
########################################################################
sub exec_acc_sqlcount {
	my ($sqlcmd) = @_;
	my $count = exec_sqlcount($sqlcmd, $CONF_DB_USER);

	return $count;
}

########################################################################
#  input: $sqlfile, $outfile
#  output: See exec_sqlfile()
#  desc: See exec_sqlfile()
########################################################################
sub exec_fs_sqlfile {
	my ($sqlfile, $outfile) = @_;
	my $res = exec_sqlfile($sqlfile, $outfile, $CONF_DB_FS);
	return $res;
}

########################################################################
#  input: $sqlcmd, $outfile
#  output: See exec_sqlcmd()
#  desc: See exec_sqlcmd()
########################################################################
sub exec_fs_sqlcmd {
	my ($sqlcmd, $outfile) = @_;
	my $res = exec_sqlcmd($sqlcmd, $outfile, $CONF_DB_FS);
	return $res;
}

########################################################################
#  input: $sqlcmd
#  output: See exec_sqlcount()
#  desc: See exec_sqlcount()
########################################################################
sub exec_fs_sqlcount {
	my ($sqlcmd) = @_;
	my $count = exec_sqlcount($sqlcmd, $CONF_DB_FS);
	return $count;
}

########################################################################
#  input: $sqlfile, $outfile
#  output: See exec_sqlfile()
#  desc: See exec_sqlfile()
########################################################################
sub exec_log_sqlfile {
	my ($sqlfile, $outfile) = @_;
	my $res = exec_sqlfile($sqlfile, $outfile, $CONF_DB_LOG);
	return $res;
}

########################################################################
#  input: $sqlcmd, $outfile
#  output: See exec_sqlcmd()
#  desc: See exec_sqlcmd()
########################################################################
sub exec_log_sqlcmd {
	my ($sqlcmd, $outfile) = @_;
	my $res = exec_sqlcmd($sqlcmd, $outfile, $CONF_DB_LOG);
	return $res;
}

########################################################################
#  input: $sqlcmd
#  output: See exec_sqlcount()
#  desc: See exec_sqlcount()
########################################################################
sub exec_log_sqlcount {
	my ($sqlcmd) = @_;
	my $count = exec_sqlcount($sqlcmd, $CONF_DB_LOG);
	return $count;
}

########################################################################
#  input: $sqlfile, $outfile
#  output: See exec_sqlfile()
#  desc: See exec_sqlfile()
########################################################################
sub exec_um_log_sqlfile {
	my ($sqlfile, $outfile) = @_;
	my $res = exec_sqlfile($sqlfile, $outfile, $CONF_DB_UM_LOG);
	return $res;
}

########################################################################
#  input: $sqlcmd, $outfile
#  output: See exec_sqlcmd()
#  desc: See exec_sqlcmd()
########################################################################
sub exec_um_log_sqlcmd {
	my ($sqlcmd, $outfile) = @_;
	my $res = exec_sqlcmd($sqlcmd, $outfile, $CONF_DB_UM_LOG);
	return $res;
}

########################################################################
#  input: $sqlcmd
#  output: See exec_sqlcount()
#  desc: See exec_sqlcount()
########################################################################
sub exec_um_log_sqlcount {
	my ($sqlcmd) = @_;
	my $count = exec_sqlcount($sqlcmd, $CONF_DB_UM_LOG);
	return $count;
}

########################################################################
#  Do not directly use this sub-routine! Plz use exec_xxx_sqlfile().
#  input: $sqlfile, $outfile, $dbfile
#  output: [$rtncode] 0=OK, others = fail(5=db lock, 19=is not unique)
#  desc: 
#    1. General purpose for executing insert/delete/update sql
#    2. General purpose for query db and dump result to $outfile
########################################################################
sub exec_sqlfile {
	my ($sqlfile, $outfile, $dbfile) = @_;
	print "exec_sqlfile\n";
	if (!-f $sqlfile) {
		return 1;
	}
	
	my $command = "$SQLITE_CMD $CONF_DB_USER < $sqlfile";
	# compatible issue
	if (defined($dbfile)) {
		$command = "$SQLITE_CMD $dbfile < $sqlfile";
	}

	if (defined($outfile)) {
		$command .= " > $outfile";
	}
	#print "exec: $command\n";
	my $dbres = system($command);
	if ($dbres != 0) {
		print "exec_sqlfile dbres=$dbres\n";
		if ($dbres == 0xB00 || $dbres == 256) {
			naslog($LOG_NAS_FW, $LOG_ERROR, "50", "Start to fix the malformed database.");
			my $sql = "/mnt/other/tempsql";
			my $newdb = "/mnt/other/newdb";
			print "Start the \"malformed database\" handler...\n";
			# Dump SQL command from malformed database
			system("$SQLITE_CMD -cmd \".output $sql\" -cmd \".dump\" $dbfile \"\"");
			# Replace ROLLBACK with COMMIT
			system("sed -i -e 's/ROLLBACK;/COMMIT;/' $sql");
			# Create new database
			system("$SQLITE_CMD -cmd \".read $sql\" $newdb \"\"");
			# make sqlite3 command with new database
			system("$MV_CMD $newdb $dbfile");
			my $cmd = "$SQLITE_CMD $newdb < $sqlfile";
			if (defined($outfile)) {
				$cmd .= " > $outfile";
			}
			# execute again
			$dbres = system($cmd);			
#			$dbres = system($command);
			unlink($sql);
			unlink($newdb);
		}else{
			print "exec: $command error\n";
		}
	}
	unlink($sqlfile);
	return $dbres;
}

########################################################################
#  Do not directly use this sub-routine! Plz use exec_xxx_sqlcmd().
#  input: $sqlcmd, $outfile, $dbfile
#  output: [$rtncode] 0=OK, others = fail(5=db lock, 19=is not unique)
#  desc:
#    1. General purpose for executing insert/delete/update sql
#    2. General purpose for query db and dump result to $outfile
########################################################################
sub exec_sqlcmd {
	my ($sqlcmd, $outfile, $dbfile) = @_;

	my $command = "$SQLITE_CMD $CONF_DB_USER \"$sqlcmd\"";
	# compatible issue
	if (defined($dbfile)) {
		$command = "$SQLITE_CMD $dbfile \"$sqlcmd\"";
	}

	if (defined($outfile)) {
		$command .= " > $outfile";
	}
#	print "exec: $command\n";
	my $dbres = system($command);
	if ($dbres != 0) {
		print "exec_sqlcmd dbres=$dbres\n";
		if ($dbres == 0xB00) {
#			print "========================\n";
#			print "$CP_CMD $dbfile /mnt/other/malformed.db\n";
#			system("$CP_CMD $dbfile /mnt/other/malformed.db");
			my $sql = "/mnt/other/tempsql";
			my $newdb = "/mnt/other/newdb";
			naslog($LOG_NAS_FW, $LOG_ERROR, "50", "Start to fix the malformed database.");
			print "Start the \"malformed database\" handler...\n";
			# Dump SQL command from malformed database
			system("$SQLITE_CMD -cmd \".output $sql\" -cmd \".dump\" $dbfile \"\"");
			# Replace ROLLBACK with COMMIT
			system("sed -i -e 's/ROLLBACK;/COMMIT;/' $sql");
			# Create new database
			system("$SQLITE_CMD -cmd \".read $sql\" $newdb \"\"");
			# make sqlite3 command with new database
			my $cmd = "$SQLITE_CMD $newdb < $sqlfile";
			if (defined($outfile)) {
				$cmd .= " > $outfile";
			}
			system("$MV_CMD $newdb $dbfile");
			$dbres = system($command);
			unlink($sql);
			unlink($newdb);
		}else{

		# @todo: write log to special log file
			print "exec: $command error\n";
		}	
	}
	return $dbres;
}

########################################################################
#  Do not directly use this sub-routine! Plz use exec_xxx_sqlcount().
#  input: $sqlcmd, $dbfile
#  output: $count -1=FAIL, 0~N=count
#  desc:
#    1. General purpose for executing select count(0) sql
########################################################################
sub exec_sqlcount {
	my ($sqlcmd, $dbfile) = @_;
	my $outfile = gen_random_filename("");

	my $command = "$SQLITE_CMD $CONF_DB_USER \"$sqlcmd\"";
	# compatible issue
	if (defined($dbfile)) {
		$command = "$SQLITE_CMD $dbfile \"$sqlcmd\"";
	}
	$command .= " > $outfile";

	#print "exec: $command\n";
	my $dbres = system($command);
	if ($dbres != 0) {
		# @todo: write log to special log file
		print "exec: $command error\n";
		unlink($outfile);
		return -1;
	}
	
	# get count
	$count = -1;
	open(my $IN, "<$outfile");
	while (<$IN>) {
		if (/(\d+)/) {
			$count = $1;
		}
		last;
	}
	close($IN);
	unlink($outfile);

	return $count;
}

return 1;  # this is required.
