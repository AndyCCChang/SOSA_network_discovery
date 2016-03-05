###################################################################
#  (C) Copyright Promise Technology Inc., 2013 All Rights Reserved
#  Name: lib/UM_log_db_lib.pl
#  Author: Olive
#  Modifier:
#  Date: 2013/03/26
#  Description: Common functions for other perls.
###################################################################

require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/db_lib.pl";
require "/nasapp/perl/lib/log_def.pl";

########################################################################
#  input: $lognum, $message
#  output: $res
#  desc: Save user mode log message into database
#  example: $res = UMnaslog("log functionality", "log level", "log num", "Create share disk fails");
########################################################################
sub UMnaslog {
	use File::Basename;
	my ($caller_package, $caller_filename, $caller_line) = caller;
	my ($logfunc,$loglevel,$lognum, $message) = @_;

	# generate SQL
	my $sqlcmd = "insert into USERM_LOG (logfunc, loglevel, lognum, message, logtime) values (";
	$sqlcmd .= "'$logfunc','$loglevel','$lognum', '$message', strftime('%Y-%m-%d %H:%M:%S', 'now', 'localtime'));";
	my $dbres = exec_um_log_sqlcmd($sqlcmd);
    
	return 0;
}

########################################################################
#  input: $search
#  output: [$count]
#  desc: get count of total logs in database.
########################################################################
sub get_UMlogs_count {
	my ($search,$search_type) = @_[0];
	my $count = 0;
	my $searchSQL = "";
	if (defined($search) && $search ne "") {
		if($search_type == 0){
			$searchSQL = "where logfunc == '$search'";
		}
		elsif($search_type == 1){
			$searchSQL = "where loglevel == '$search'";
		}
	}
	$tmpfile = gen_random_filename("");
	my $querySQL = "select count(0) from USERM_LOG $searchSQL;";
	$count = exec_um_log_sqlcount($querySQL);

	return $count;
}

return 1;  # this is required.