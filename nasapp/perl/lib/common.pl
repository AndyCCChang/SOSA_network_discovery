###################################################################
#  (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: lib/common.pl
#  Author: Fred, Olive
#  Modifier:
#  Date: 2012/10/19
#  Parameter: None
#  OutputKey: None
#  ReturnCode: None
#  Description: Common functions for other perls.
###################################################################

require "/nasapp/perl/lib/default_def.pl";
require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/dir_path.pl";
require "/nasapp/perl/lib/acc_lib.pl";

my $SYS_BUSY_FILE="/tmp/sysbusy";				# Flag file to check whether other LVM or FS process is running

########################################################################
#	input:	[Araay of Hash ref, filename under "/tmp" , sepearator]
#	output:	[0/1]
########################################################################
sub gen_output
{
	my ($data_ref,$filename,$append,$sep)=@_;
	my @data=@$data_ref;
	my $separator=chr(4).' | '.chr(4);
	#my $separator="\x4 | \x4";
#	my $emptystr="\x7";
	my $need_append=0;
	my $OUT;
	if(defined($sep)){
		$separator=$sep;
	}
	if(defined($append)){
		$need_append=$append;
	}
	
	if($need_append){
		open ($OUT, ">>".$filename);
	}else{
		open ($OUT, ">".$filename);
	}

	if(scalar(@data)>0){
		#		Print Keys
		#for $key ( sort (keys($data[0])) ) {
		for $key (keys(%{$data[0]}) ) {
			print $OUT $key.$separator;
		}
		print $OUT "\n";
		
		#		Print Data
		for $href ( @data ) {
			#for $key ( sort (keys(%$href)) ) {
			for $key ( keys (%$href))  {
				print $OUT $href->{$key}.$separator;
			}
			print $OUT "\n";
		}
	}

	close ($OUT);
	return 0;
}

########################################################################
#	input:	%hash: Hash of parameters to be writed (pass by reference)
#           $outfile: file to be write
#	output:	[0/1]
########################################################################
sub gen_output_extra_hash
{
	my ($data_ref, $outfile) = @_;
	my %data = %$data_ref;
	open(my $OUT, ">".$outfile."ext");
	foreach $key (keys %data) {
		print $OUT "$key = $data{$key}\n";
	}
	close($OUT);
	return 0;
}

########################################################################
#	input:	[ $size ,$unit	]
#	output:	[ size in MB]
########################################################################
sub changeunit
{
    my ($size, $unit ) = @_;

    if ( $unit eq 'T' ) {
         $size = $size * 1024 * 1024;
    }elsif ( $unit eq 'G' ) {
         $size = $size * 1024;
    }

    return $size;
}


########################################################################
#	input:	X
#	output:	0
#	Desc: function to mark sys_busy
########################################################################
sub mark_sysbusy{
	open(my $OUT,">$SYS_BUSY_FILE");
	close($OUT);
	return 0;
}
########################################################################
#	input:	X
#	output:	0
#	Desc: function to remove sys_busy
########################################################################
sub remove_sysbusy{
	if ( -e $SYS_BUSY_FILE){
		unlink($SYS_BUSY_FILE);
	}
	return 0;
}
########################################################################
#	input:	X
#	output:	 0/1 
#	Desc: function to check sys_busy
########################################################################
sub check_sysbusy{
	if ( -e $SYS_BUSY_FILE){
		return 1;
	}
	return 0;
}
########################################################################
#	input:	[ array of hash reference	]
#	output:	[ X ]
########################################################################
sub print_AOH{
	my ($data_ref)=@_;
	my @data=@$data_ref;
	for $href ( @data ) {
		print "{ ";
		for $role ( keys %{$href} ) {
			 print "$role=$href->{$role} ";
		}
		print "}\n";
	}
	
}

########################################################################
#	input: [msg]
#	output:	 nono
#	Desc: function to internal debug , debug file located in /tmp/debug
########################################################################
sub debug{
	my ($data)=@_;
	open(my $DEBUG,">>/tmp/debug");
		print $DEBUG "$data\n";
	close($DEBUG);
}
########################################################################
#	input: string or vector
#	output:	 string or vector
#	Desc: function to remove unnecessary space in beginning or ending of
#		  the string
########################################################################
sub trim {
    my $string = shift;
    $string =~ s/^\s+//;  
    $string =~ s/\s+$//;  
    return $string;
}
########################################################################
#	input: hostname, domain_name
#	output:
#	Desc: Write hostname and domain name to /etc/hosts
########################################################################
sub set_conf_hosts {
	my ($hostname, $domain_name)=@_;
	# Update /etc/hosts
	my $hostout = gen_random_filename($CONF_HOSTS);
	open(my $OUT, ">$hostout");
	print $OUT "127.0.0.1\tlocalhost.localdomain\tlocalhost\n";
	open(my $IN,"$IFCONFIG_CMD |");
	while(<$IN>) {
		if ( /inet\s+addr:(\S+)\s+Bcast:\S+\s+Mask:\S+/ ) {
			$ip = $1;
			if ($domain_name eq "") {
				print $OUT "$ip\t$hostname\t$hostname\n";
			}
			else {
				print $OUT "$ip\t$hostname.$domain_name\t$hostname\n";
			}
		}
	}
	close($IN);
	close($OUT);
	system("ln -sf $CONF_HOSTS /etc/hosts");
	system("$CP_CMD -f $hostout $CONF_HOSTS");
	unlink($hostout);
}
########################################################################
#	input:	[ x	]
#	output:	%data
#	Description: hash data of LV name and mount path
########################################################################
sub get_lv_mountmap{
	#/dev/mapper/c_vg0001-lv001 on /FS/homes type gfs2 (rw,noatime,nodiratime,hostdata=jid=0,quota=on)

	%data=();
	open(my $MIN,"$MOUNT_CMD |");
	while(<$MIN>){
		if(/\/dev\/mapper\/(\S+)\s+on\s+(\/\S+)/){
			$data{$1}=$2;			# "c_vg0001-lv001"=> "/FS/homes"
		}
	}
	close($MIN);
	
	return %data;
}
########################################################################
#	input: [$name,$quota_value]
#	output:	 0/1 
#	Desc: function to set quota value
########################################################################
sub chk_nameisgroup{
	my $name=@_[0];

	if ($name =~ /^\@([\S\s]*)/) { #Group
		return 1; #for group
	} else { #User
		return 0;
	}
}
########################################################################
#	input: [$name,$quota_value]
#	output:	 0/1 
#	Desc: function to set quota value
########################################################################
sub set_quota{
	my ($name, $quota_value, $mount)=@_;

	$flag = chk_nameisgroup($name);

	if ($flag == 1) { #Group
		if ($name =~ /^\@([\S\s]*)/) { #Group
			$name = $1;
		}
		# Check quota is bigger than group's used size or not

		#get group current used amount
		$command = "$GFS2QUOTA_CMD get -g $name -f $mount";
		open(my $CIN,"$command |");
		while(<$CIN>){
			#group        smb:  limit: 0.0        warn: 0.0        value: 0.0
			if (/^group\s+(\S+)\:\s+(limit)\:\s+(\d+\.*\d*)\s+(warn)\:\s+(\d+\.*\d*)\s+(value)\:\s+(\d+\.*\d*)/) {
				if ($name eq "$1") {
					$used_capacity = $7;
					last;
				}
			}
		}
		close($CIN);

		#new setting quota amount should be bigger then zero and used amount.
		if (($quota != 0) && ($quota <= $used_capacity)) {
			return 2;
		}

		#set quota
		my $ret=system("$GFS2QUOTA_CMD limit -g $name -l $quota_value -f $mount");
		if($ret > 0){
			return 3;
		}
	}else{ #User
		# Check quota is bigger than user's used size or not

		#get user current used amount
		$command = "$GFS2QUOTA_CMD get -u $name -f $mount";
		open(my $DIN,"$command |");
		while(<$DIN>){
			#user    testuser:  limit: 0.0        warn: 0.0        value: 0.0

			if (/^user\s+(\S+)\:\s+(limit)\:\s+(\d+\.*\d*)\s+(warn)\:\s+(\d+\.*\d*)\s+(value)\:\s+(\d+\.*\d*)/) {
				if ($Name eq "$1") {
					$used_capacity = $7;
					last;
				}
			}
		}
		close($DIN);

		#new setting quota amount should be bigger then zero and used amount.
		if (($quota != 0) && ($quota <= $used_capacity)) {
			exit 2;
		}

		#set quota
		my $ret = system("$GFS2QUOTA_CMD limit -u $name -l $quota_value -f $mount");
		if($ret > 0){
			return 3;
		}
	}
}
########################################################################
#	input: [$name,$quota_value]
#	output:	 0/1 
#	Desc: function to set quota value
########################################################################
sub clear_quota{
	my ($name, $quota_value, $mount)=@_;
	my $ret=0;

	$flag = chk_nameisgroup($name);

	if($flag == 1)#group
	{
		if ($name =~ /^\@([\S\s]*)/) { 
			$name = $1;
		}
		$ret=system("$GFS2QUOTA_CMD limit -g $name -l $quota_value -f $mount");
	}
	else{#user
		$ret=system("$GFS2QUOTA_CMD limit -u $name -l $quota_value -f $mount");
	}
	
	return $ret;
}
########################################################################
#	input: [$file_pathname]
#	output:	 random 'full' pathname in temp
#	Desc: function to get random filename to copy/write for config or otherwise in "/tmp"
#			random append string use the uuid method
########################################################################
sub gen_random_filename
{
	use File::Basename;
	my ($caller_package, $caller_filename, $caller_line) = caller;
	my ($config_name)=@_;
	my $uuid=`$UUIDGEN_CMD`;
	chomp $uuid;
	my $prefix=($config_name eq "")?"":basename($config_name)."_";
	return "/tmp/$prefix".basename($caller_filename)."_L$caller_line"."_$uuid";
}
########################################################################
#	input: [$source,$destination]
#	output: 0=success, 1=No such file or directory of destination
#	Desc: copy $source to $destination correctly if $destination is a link
########################################################################
sub copy_file_to_realpath
{
	my ($source, $destination)=@_;
	my $realpath=`$REALPATH_CMD $destination 2>/dev/null`;
	chomp($realpath);
	
	if ($realpath ne "") {
		system("$CP_CMD -f $source $realpath");
	}
	else {
		return 1;
	}
	return 0;
}

########################################################################
#	input: [$check_value]
#	output: 0=not int, 1= is int
#	Desc: check the input is a int or not
########################################################################
sub isInt{
  my $val = shift;
  if($val =~ /^\d+$/){
	return 1;
  }else{
	return 0;
  }
}

########################################################################
#	input: [$file]
#	output: -1: not text file or not exist, 0~n: count of lines
#	Desc: Count how many lines of $file
########################################################################
sub count_line {
	my $file = shift;
	if (!-f $file) {
		return -1;
	}
	my $count = 0;
	print "$WC_CMD -l $file\n";
	open(my $IN, "$WC_CMD -l $file |");
	while (<$IN>) {
		print $_."\n";
		if (/(\d+)/) {
			$count = $1;
		}
		last;
	}
	close($IN);
	return $count;
}
#####################################################
#	Convert timestamp to given format
#		Parameter:
#			timestamp,format (year,mon,day,hour,min,sec)
#####################################################
sub get_datetime_string{
	my ($time,$format)= @_;
	
	if(!defined($format)){
		$format='%04d/%02d/%02d %02d:%02d:%02d';
	}
	# get date
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
    $year += 1900;
    $mon += 1;
    my $result = sprintf($format,$year, $mon, $mday, $hour, $min, $sec);
	return $result;
}
#####################################################
#	Convert secs to general [d h m s] format
#		Parameter:
#			sec
#####################################################
sub convert_time_to_dhms { 
	my $time = shift;
	my $days = int($time / 86400); 
	$time -= ($days * 86400); 
	my $hours = int($time / 3600); 
	$time -= ($hours * 3600); 
	my $minutes = int($time / 60); 
	my $seconds = $time % 60; 

	$days = $days < 1 ? '' : $days .'d '; 
	$hours = $hours < 1 ? '' : $hours .'h '; 
	$minutes = $minutes < 1 ? '' : $minutes . 'm '; 
	$time = $days . $hours . $minutes . $seconds . 's'; 
	return $time; 
}	
#####################################################
#	Get current program hosted controller id
#	(in this platform,is the same as slot id)
#	Output: 0/1
#####################################################
sub get_current_ctrlid{
	my $ctrlid=`$GETHISCTLRINFO_CMD -c`;
	chomp($ctrlid);
	return $ctrlid;
}
#####################################################
#	Get Master controller id
#####################################################
sub get_master_ctrlid{
	my $master_ctrlid="";
	my $current_ctrlid=get_current_ctrlid();
	my $isMaster=`$GETHISCTLRINFO_CMD -m`;
	chomp($isMaster);
	if($isMaster){
		$master_ctrlid=$current_ctrlid;
	}else{
		$master_ctrlid=($current_ctrlid == "1")?"0":"1";
	}
	return $master_ctrlid;
}
#####################################################
#	Get limits according to the DIMM Size
#	Input:X
#	Output: HASH of limits
#	Ex.	{'max_sd_count' =>256,'max_connections' =>1024,'max_sd_size' =>67108864,'max_domain_group_count' =>10000,'max_user_count' =>10000 }
#####################################################
sub get_limits{
	my %data=();
	if(! -e $CACHE_SYS_LIMITS){
		my $dimm_size=0;	#kB
		open(my $MEM_IN,"$CAT_CMD /proc/meminfo |grep MemTotal |");
		while(<$MEM_IN>){
			if(/MemTotal:\s+(\d+)\s+/){		
				$dimm_size=$1;
			}
		}
		close($MEM_IN);
		
		$dimm_size=$dimm_size/1024/1024*2;	# GB	,reserved only half for system
		
		my ($max_sd_size,$max_sd_count,$max_connections,$max_domain_group_count,$max_user_count)=
		(4*1024*1024,256,64,1000,1000);	#	max_sd_size Unit: MB
		
		my @dimm_rank=			(2,4,8,16);
		my @sd_size_rank=		(4*1024*1024,16*1024*1024,32*1024*1024,64*1024*1024);
		my @sd_count_rank=		(256,256,256,256);
		my @conn_rank=			(64,256,512,1024);
		my @group_count_rank=	(1000,2000,5000,10000);
		my @user_count_rank=	(1000,2000,5000,10000);
		my $min_index=0,$min=99999;
		for my $i (0 .. $#dimm_rank) {
			if(abs($dimm_size -$dimm_rank[$i])<$min){
				$min=abs($dimm_size -$dimm_rank[$i]);
				$min_index=$i
			}
		}
		#print "$dimm_size,$min,$min_index,$dimm_rank[$min_index]\n";
		$max_sd_size=$sd_size_rank[$min_index];
		$max_sd_count=$sd_count_rank[$min_index];
		$max_connections=$conn_rank[$min_index];
		$max_domain_group_count=$group_count_rank[$min_index];
		$max_user_count=$user_count_rank[$min_index];

		$data{'max_sd_size'}=$max_sd_size;
		$data{'max_sd_count'}=$max_sd_count;
		$data{'max_connections'}=$max_connections;
		$data{'max_domain_group_count'}=$max_domain_group_count;
		$data{'max_user_count'}=$max_user_count;
		open(my $CACHE,">$CACHE_SYS_LIMITS");
		while(my ($key,$value)=each(%data)){
			print $CACHE "$key=$value\n";
		}
		close($CACHE);
	}else{
		open(my $CACHE,"<$CACHE_SYS_LIMITS");
		while(<$CACHE>){
			if(/(\S+)=(\S+)/){
				$data{"$1"}=$2;
			}
		}		
		close($CACHE);
	}
	
	
	return %data;
}
#####################################################
#	Get perl system() exit code 
#	Usage: sytem("xx"); my $ret=get_system_exit($?);
#	Output: get real exit code from system
#####################################################
sub get_system_exit{
     my $ret=shift;
     if($ret == -1){
        return 1;       #execute fail
     }elsif($ret & 127){
        return 1;       #child die
     }else{
        return $ret >>8; #exit code
     }
}

####################################################
#  Get random number from /dev/urandom
#  Usage : $r = &get_random(8)
#  Output : get the random value , length = 8
####################################################
sub get_random {

	my $num = shift;
	$num = 2 if ($num < 0);
	open(my $fh, '<', '/dev/urandom');
	read($fh, my $buff, 16);
	close $fh;
	my @seed = unpack 'L4' , $buff;
	my $string = join('', @seed);
	$string = $string x 5;
	return substr($string, 0, $num);
}

####################################################
#  scp file to remote side
#  Input :	[ $remote_ip, $local_file, $remote_file	]
#  Output : 0(success) / 1(fail) 
####################################################
sub scp_file_to {

	my ($remote_ip, $local_file, $remote_file) = @_;
	my $ret = 0;
	system("sshpass -p 'promise' scp -o StrictHostKeyChecking=no -r $local_file $remote_ip:$remote_file");
	if ( $? != 0 ) {
		$ret = 1;
	}
	return $ret;
}
####################################################
#  scp file from remote side
#  Input :  [ $remote_ip, $local_file, $remote_file ]
#  Output : 0(success) / 1(fail)
####################################################
sub scp_file_from {

	my ($remote_ip, $local_file, $remote_file) = @_;
	my $ret = 0;
	system("sshpass -p 'promise' scp -o StrictHostKeyChecking=no -r $remote_ip:$remote_file $local_file");
	if ( $? != 0 ) {
		$ret = 1;
	}
	return $ret;
}

sub rsync_file_from {
	my ($remote_ip, $local_file, $remote_file) = @_;
	my $ret = 0;
	system("/usr/bin/rsync -avS --password-file=/etc/rsyncd.secrets.client rsyncuser@" . $remote_ip . "::server1/" . $local_file . " " . $remote_file);
    if ( $? != 0 ) {
        $ret = 1;
    }
    return $ret;


}

sub rsync_fw_file_from {
	my ($remote_ip, $local_file, $remote_file) = @_;
	my $ret = 0;
	system("/usr/bin/rsync -avS --password-file=/etc/rsyncd.secrets.client rsyncuser@" . $remote_ip . "::server2/" . $remote_file . " " . $local_file);
    if ( $? != 0 ) {
        $ret = 1;
    }
    return $ret;


}

sub rsync_file_to {
	my ($remote_ip, $local_file, $remote_file) = @_;
	my $ret = 0;
	system("/usr/bin/rsync -avS --password-file=/etc/rsyncd.secrets.client " . $local_file . " rsyncuser@" . $remote_ip . "::server3/" . $remote_file);
    if ( $? != 0 ) {
        $ret = 1;
    }
    return $ret;


}

return 1;  # this is required.
