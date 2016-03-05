#!/usr/bin/perl
#rmtrep related function for G-Class.
sub set_rmtrep_task
{# if local_sd is null, delete the task
#ret 0:no schedule change, 1:schedule change, 2:set failed
#set_rmtrep_task("1", "1", "fs1", "192.168.11.161", "fss1", "1D", "0", "1254654654");
	my ($task_id, $local_sd, $remote_cluster_ip, $remote_sd, $retry, $option) = @_;
	
	my $conf_file = "/nasdata/config/etc/RmtRep.conf";	
	
	my @cont = ();
	open(my $IN, "$conf_file");
	@cont = <$IN>;
	close($IN);

	my $out = "";
	my $ret = 0;
	foreach $line (@cont) {
		if($line =~ /(\d+)\t(\S+)\t(\d+\.\d+\.\d+\.\d+)\t(\S+)\t(\d+)\t(\d+)/) {#formal pattern
			$cur_task_id = $1;
			$cur_local_sd = $2;
			$cur_remote_cluster_ip = $3;
			$cur_remote_sd = $4;
			$cur_retry = $6;
			$cur_option = $7;
			if($cur_task_id == $task_id) {
				print "There is already a task with the same task id.\n";				
				return 1;
			} else {
				$out .= $line;
			}			
		} elsif($line =~ /(\d+)\n/) {
			$cur_task_id = $1;
			if($cur_task_id == $task_id) {
				$match = 1;
				$out .= "$task_id\t$local_sd\t$remote_cluster_ip\t$remote_sd\t$retry\t$option\n";
			} else {
				$out .= $line;
			}
		}
	}
	if($match == 0) {
		$out .= "$task_id\t$local_sd\t$remote_cluster_ip\t$remote_sd\t$retry\t$option\n";
	}
	
	my $tmp_file = "/tmp/RmtRep.conf";
    open(my $OUT, ">$tmp_file");
    print $OUT $out;
    close($OUT);
	system("mv $tmp_file $conf_file");
	return 0;
}
sub del_rmtrep_task
{
	my ($task_id) = @_;
	my $conf_file = "/nasdata/config/etc/RmtRep.conf";	
	return 2 if(!-e $conf_file);
	my @cont = ();
	open(my $IN, "$conf_file");
	@cont = <$IN>;
	close($IN);

	my $out = "";
	my $count = 1;
	my $match = 0;
	my $schedule_change = 0;
	foreach $line (@cont) {
		if($line =~ /(\d+)\t(\S+)\t(\d+\.\d+\.\d+\.\d+)\t(\S+)\t(\d+)\t(\d+)/) {#formal pattern
			$cur_task_id = $1;
			if($cur_task_id == $task_id) {#modify this line, clean the last_date as well, unless the $late_data is not null
				$out .= "$task_id\n";
				$match = 1;
			} else {
				$out .= $line;
			}
			
		} else {
			$out .= $line;
		}
	}
	if($match == 0) {
		print "Cannot find match task_id:$task_id in $conf_file.\n";
		return 2;
	}
	
	my $tmp_file = "/tmp/RmtRep.conf";
    open(my $OUT, ">$tmp_file");
    print $OUT $out;
    close($OUT);
	system("mv $tmp_file $conf_file");
	return 0;
}
sub get_rmtrep_task
{	
	my $conf_file = "/nasdata/config/etc/RmtRep.conf";	
	my @task_info = ();
	my @cont = ();
	open(my $IN, "$conf_file");
	@cont = <$IN>;
	close($IN);

	my $task_id = "";
	my $out = "";
	my $count = 1;
	foreach $line (@cont) {
		if($line =~ /(\d+)\t(\S+)\t(\d+\.\d+\.\d+\.\d+)\t(\S+)\t(\d+)\t(\d+)/) {#formal pattern
			$cur_task_id = $1;
			$cur_local_sd = $2;
			$cur_remote_cluster_ip = $3;
			$cur_remote_sd = $4;
			$cur_retry = $5;
			$cur_option = $6;
			push @task_info,{
				"task_id" =>$cur_task_id,
				"local_sd" =>$cur_local_sd,
				"remote_cluster_ip" =>$cur_remote_cluster_ip,
				"remote_sd" =>$cur_remote_sd,
				"retry" =>$cur_retry,
				"option" =>$cur_option,		
			};			
		} elsif($line =~ /(\d+)\n/) {
			$cur_task_id = $1;
			push @task_info,{
				"task_id" =>$cur_task_id,
				"local_sd" =>"",
				"remote_cluster_ip" =>"",
				"remote_sd" =>"",
				"retry" =>"",
				"option" =>""
			};				
		}
	}
	return @task_info;
}
return 1;  # this is required.
