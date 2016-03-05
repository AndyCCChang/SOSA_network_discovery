###################################################################
#  (C) Copyright Promise Technology Inc., 2013 All Rights Reserved
#  Name: lib/log_db_lib.pl
#  Author: Kylin
#  Modifier:
#  Date: 2013/03/11
#  Description: Common functions for other perls.
###################################################################

require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/db_lib.pl";
require "/nasapp/perl/lib/log_def.pl";
########################################################################
#  input: $lognum, $message
#  output: $res
#  desc: Save log message into database
#  example: $res = naslog("log functionality", "log level", "log num", "Create Share Disk fails");
########################################################################
sub naslog {
	use File::Basename;
	my ($caller_package, $caller_filename, $caller_line) = caller;
	my ($logfunc,$loglevel,$lognum, $message) = @_;
	#print "caller_package = $caller_package\n";
	#print "caller_filename = $caller_filename\n";

	# generate SQL
	$message = escape_single_quote($message);
    my $gm_time=gmtime();
    my($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst)=gmtime();
    $year += 1900;
	$mon  += 1;
	my $btime = sprintf("%d-%02d-%02d %02d:%02d:%02d",$year,$mon,$day,$hour,$min,$sec);
	my $sqlcmd = "insert into EVENT_LOG (logfunc, loglevel, lognum, caller, line, message, logtime) values (";
	$sqlcmd .= "'$logfunc','$loglevel','$lognum','$caller_filename', '$caller_line', '$message','$btime');";

	my $dbres = exec_log_sqlcmd($sqlcmd);
	#sync log cmd to another controller
    $count = get_logs_count(3,"","");                                      
	system("touch /tmp/eventadd"); #hanly add for log 
	print " $count\n";
    if($count > 1000){                                                                                                    
          my $sqlcmd = "delete from EVENT_LOG where logidx in (select MIN(logidx) from EVENT_LOG);";                   
          my $dbres = exec_log_sqlcmd($sqlcmd);                                                                        
	}             
    
	return 0;
}
########################################################################
#  input: $search
#  output: [$count]
#  desc: get count of total logs in database.
########################################################################
sub get_logs_count {
	my ($filter,$search,$search_type) = @_;
	my $count = 0;
	my $searchSQL = "where A.[loglevel]<= $filter";
	if (defined($search) && $search ne "") {
		if($search_type == 0){
			$searchSQL = ",A.[logfunc] == '$search'";
		}
		elsif($search_type == 1){
			$searchSQL = ",A.[loglevel] == '$search'";
		}
	}
	$tmpfile = gen_random_filename("");
	my $querySQL = "select count(0) from EVENT_LOG as A $searchSQL;";
	$count = exec_log_sqlcount($querySQL);

	return $count;
}

return 1;  # this is required.
