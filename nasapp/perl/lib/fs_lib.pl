###################################################################
#  (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: lib/fs_lib.pl
#  Author: Fred
#  Modifier:
#  Date: 2012/11/19
#  Parameter: None
#  OutputKey: None
#  ReturnCode: None
#  Description: Common functions for other perls.
#  Sub function list:
#		get_vol_info
#		get_vgname_vgfree_map
#		get_all_hidden_disk_info
#		get_share_disk_info
#		get_ld_devmap
#		get_df_info
#		get_accept_mount_device
#		get_vgfree_size
#		get_i2_array_info
#		merge_vol_i2_info
#		update_fsck_log_record
#		mark_fs_checking
#		remove_fs_checking
#		check_sd_missing
#		mark_sd_missing
#		check_sd_formatting
#		check_sd_checking
#		insert_db_volume_info
#		update_db_volume_info
#		delete_db_volume_info
#		insert_db_sharedisk_info
#		update_db_sharedisk_lvminfo
#		check_missing_sd_to_db
#		flush_db_volume_info
#		check_sdname_exist
#		get_vol_status_map
###################################################################

require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/bk_ssh_lib.pl";
require "/nasapp/perl/lib/pro_lib.pl";
require "/nasapp/perl/lib/fs_crypt_lib.pl";
require "/nasapp/perl/lib/fs_db_lib.pl";
require "/nasapp/perl/lib/log_db_lib.pl";


*ENCRYPT_LV_POSTFIX=\"_crypt";
*HIDDEN_SD_POSTFIX=\"=hiddensd";

#	Share disk general path
*SD_FS_FOLDER=\"/FS";
*SD_FC_FOLDER=\"/FC";
*SD_ISO_FOLDER=\"/FS";
*SD_SNAPSHOT_FOLDER=\"/FS";

#	Share Disk type [cluster,standard,snapshot,ISO]
*SD_TYPE_CLUSTER=\"cluster";
*SD_TYPE_STANDARD=\"standard";
*SD_TYPE_SNAPSHOT=\"snapshot";
*SD_TYPE_ISO=\"iso";
*SD_TYPE_HIDDEN=\"hidden";

#	size limit
*MIN_SD_SIZE_MB=\10240;			#10G
*HIDDEN_SD_SIZE_MB=\4096;
*MIN_SD_REQUIRED_VOLFREE_MB=\1024;

#  Share Disk encryption tag
*SD_ENCRYPT_TAG=\"encrypt";

#	Share Disk status [OK,recoverying,checking]
*SD_STATUS_OK=\"OK";
*SD_STATUS_RECOVERYING=\"Recoverying";
*SD_STATUS_CHECKING=\"Checking";
*SD_STATUS_FORMATTING=\"Formatting";
*SD_STATUS_CRITICAL=\"Critical";			#	follow the Disk Pool state
*SD_STATUS_OFFLINE=\"Offline";				#	follow the Disk Pool state
*SD_STATUS_MISSING=\"Missing";				#	from other controller or some missing , could remove manaual

#	NAS volume status [OK,initializing]
*VOL_STATUS_OK=\"OK";
*VOL_STATUS_INITIALIZING=\"Initializing";
*VOL_STATUS_CRITICAL=\"Critical";
*VOL_STATUS_OFFLINE=\"Offline";
*VOL_STATUS_MISSING=\"Missing";

#	
*VGS_INFO_CMD=\"$VGS_CMD -o vg_name,vg_size,vg_free,vg_tags --units m --noheadings ";
*VGS_PATTERN=\".*\\s+(\\S+)\\s+(\\d+)\\.\\d+m\\s+(\\d+)\\.*\\d*m\\s+raid:(\\S+),alias:(\\S+),ctrlid:(\\S+),reserve_ratio:(\\S+)";

*LVS_INFO_CMD=\"$LVS_CMD -o vg_name,lv_name,lv_size,lv_attr,lv_tags --unit m --noheadings --sort +lv_time";
*LVS_PATTERN1=\".*\\s+(\\S+)\\s+(\\S+)\\s+(\\d+)\\.\\d*m\\s+(\\S+)\\s+mount:(\\S+),(\\S+)";	#Encrypt SD
*LVS_PATTERN2=\".*\\s+(\\S+)\\s+(\\S+)\\s+(\\d+)\\.\\d*m\\s+(\\S+)\\s+mount:(\\S+)";			#Normal
*LVS_PATTERN3=\".*\\s+(\\S+)\\s+(\\S+)\\s+(\\d+)\\.\\d*m\\s+(\\S+)\\s+"; 						#Snapshot


################################################
#	Get Vol information
#	input:	[X](for all)	
#	input:	[vgname] (for spefic lvm vgname)
#	output:	Volume info AoH
#		ex	[0] -> {"vgname"=>c_vg0001,"vgsize"=>10240,"vgfree"=>1024,"volname"=>NasVol1}
#			[1]	-> {"vgname"=>c_vg0002,"vgsize"=>10240,"vgfree"=>2048,"volname"=>NasVol2}
################################################
sub get_vol_info{
	my ($arg_volname)=@_;
	my $qry_volname="";
	if(defined($arg_volname)){
		$qry_volname=$arg_volname;
	}

	my @volinfo=();
	if($qry_volname ne ""){
		@volinfo=get_vol_db($qry_volname);
	}else{
		@volinfo=get_vol_db();
	}
	
	merge_vol_i2_info(\@volinfo);
	
	my @sdinfo = get_sd_db();
	
	for my $index(@volinfo){
		my ($act_view,$act_delete,$act_extend,$act_locate,$act_rename)=(1,1,1,1,1);
		$index->{'volsize'}=$index->{'vgsize'};
		my $hidden_sdname=$index->{'volname'}.$HIDDEN_SD_POSTFIX;
		if(check_sd_formatting($hidden_sdname)){
			$index->{'status'}=$VOL_STATUS_INITIALIZING;
			$act_delete=0;
			$act_extend=0;
			$act_rename=0;
		}else{
			$index->{'status'}=$VOL_STATUS_OK;
		}
		#	UI actions
		$index->{'act_view'}=$act_view;
		$index->{'act_delete'}=$act_delete;
		$index->{'act_extend'}=$act_extend;
		$index->{'act_locate'}=$act_locate;
		$index->{'act_rename'}=$act_rename;
		
		#	merge number of sd
		my $num_of_sd=0;
		for my $idx ( @sdinfo ) {
			if($idx->{'volname'} eq $index->{'volname'} ){
				$num_of_sd++;
			}
		}
		$index->{'num_of_sd'}=$num_of_sd;
		
		#	Adjust status from ldstatus
		#{OPSTATUS_CRITICAL, 0, "Critical"},			¡´
		#{OPSTATUS_OFFLINE, 0, "Offline"},				¡´
		#{OPSTATUS_INITIALIZING, 0, "Initializing"},
		#{OPSTATUS_SYNCHRONIZING, 0, "Synchronizing"},
		#{OPSTATUS_REDCHECKING, 0, "Redundancy Checking"},
		my @ldstatus=split(/,/,$index->{'ldstatus'});
		foreach(@ldstatus){
			if($_ eq $VOL_STATUS_OFFLINE || $_ eq $VOL_STATUS_CRITICAL){
				$index->{'status'}=$_;
				last;
			}
		}
		my $master_ctrlid=get_master_ctrlid();
		$master_ctrlid++;	#	1/2
		$index->{'mount_ctrl'}=$master_ctrlid;
	}
	
	return @volinfo;
}
################################################
#	function to get vgname & vgfree map
#	input:	[X](for all)	
#	input:	[vgname] (for spefic)
#	output:	vgname & vgfree hash
#		ex. {"c_vg0001"=>10240,"c_vg0002"=>10240}
################################################
sub get_vgname_vgfree_map{
	my ($arg_vgname)=@_;
	my $qry_vgname="";
	if(defined($arg_vgname)){
		$qry_vgname=$arg_vgname;
	}
	my %data=();
	open(my $VG_IN,"$VGS_INFO_CMD $qry_vgname |");
	while(<$VG_IN>){
		if(/^vgs\s+(\S+)\s+(\d+)\.\d+m\s+(\d+)\.*\d*m\s+raid:(\S+),alias:(\S+)/){	#from get_vol_info
			my $vgname=$1;	my $vgsize=$2; my $vgfree=$3; my $raid_type=$4; my $volname=$5;
			$data{$vgname}=$vgfree;
		}
	}
	close($VG_IN);
	return %data;
}
################################################
#	Get all hidden Share Disk information 
#	input:	[X]	(for all)	
#	output:	hidden Share Disk info AoH
################################################
sub get_all_hidden_disk_info{
	# Get AoH of Share Disk information from database
	my @sdinfo = get_share_disk_info("",1);
	my @hidden_sd=();
	for my $index(@sdinfo){
		if($index->{'type'} eq $SD_TYPE_HIDDEN){
			push @hidden_sd,$index;
		}
	}
	return @hidden_sd;
}
################################################
#	Get Share Disk information 
#	input:	[X]	(for all)	
#	input:	
#			[sdname] (for spefic)
#			[list_hidden] (list hidden Share Disk or not)
#	input:  [""]  [1] ( 1: list hidden, 0:don't list hidden)
#	output:	Share Disk info AoH
################################################
sub get_share_disk_info{
	my ($qry_sdname,$arg_list_hidden) = @_;
	my $list_hidden=0;
	if(defined($arg_list_hidden)){
		$list_hidden=$arg_list_hidden;
	}
	print "Get join info..\n";
	my $cluster_ip = "none";
	open(my $JOIN_IN, "/nasdata/config/etc/join_info.conf");
	while($JOIN_IN) {
		if(/VIP=(\d+\.\d+\.\d+\.\d+)/) {
			$cluster_ip = $1;
		}
	}
	close($JOIN_IN);


	print "get_share_disk_info\n";	
	# Get AoH of Share Disk information from database
	my @sdinfo = get_sd_db($qry_sdname,$list_hidden);

	# For each Share Disk, complete other information like usage/mounted/status/...
	my ($data1_ref, $data2_ref) = get_df_info();
	my %df_info = %$data1_ref;
	my %mount_info_hash=%$data2_ref;
	%mount_info_hash=reverse(%mount_info_hash); # /FS/Backup =>/dev/mapper/c_vg2013-lv6522
#	print "get_vol_status_map\n";
#	my %vol_status_info=get_vol_status_map();
#	print "get_master_ctrlid\n";
	my $master_ctrlid=get_master_ctrlid();
	$master_ctrlid++;	#	1/2
	
	
	for (my $i=0; $i<=$#sdinfo; $i++) {
#		print "$sdinfo[$i]{'volname'};\n";
		if($sdinfo[$i]{'type'} eq "enfs"){		#ISO
#		if($sdinfo[$i]{'type'} eq "nfs"){
			$search_key=$sdinfo[$i]{'volname'};
#			print "search_key=$search_key\n";
#			$search_key=$mount_info_hash{$path};		#/dev/loopX
		}
		
#		print "key $search_key\n";
		
		# Merge system df information
		if (exists $df_info{$search_key}) {
#			$folderpath = $df_info{$search_key}{'mount_on'} . "/" . $sdinfo[$i]{"sdname"};
			if(! -d $sdinfo[$i]{"lvname"}){
				$sdinfo[$i]{"mounted"} = 0;		
			}else{
				$sdinfo[$i]{"mounted"} = 1;
			}
			print "folderpath = $folderpath mounted = " . $sdinfo[$i]{"mounted"} . "\n" ;
			$sdinfo[$i]{"usage"} = $df_info{$search_key}{'usage'};
			$sdinfo[$i]{"available"} = $df_info{$search_key}{'available'};
			$sdinfo[$i]{"used"} = $df_info{$search_key}{'used'};
			$sdinfo[$i]{"mount_on"} = $df_info{$search_key}{'mount_on'};
			$sdinfo[$i]{"mount_ctrl"} =$master_ctrlid;
			
		}
		else {
			$sdinfo[$i]{"mounted"} = 0;
			$sdinfo[$i]{"usage"} = 0;
			$sdinfo[$i]{"available"} = 0;
			$sdinfo[$i]{"used"} = 0;
			$sdinfo[$i]{"mount_on"} = "";
			$sdinfo[$i]{"mount_ctrl"} = "";
		}

		# Check status of Share Disk
#		$search_key = "/FC/$sdname";
		my $status = $SD_STATUS_OK;
#		if (exists $mount_info_hash{$search_key}) {
#			$status = $SD_STATUS_RECOVERYING;
#		}elsif(check_sd_checking($sdname)){
#			$status = $SD_STATUS_CHECKING;
#		}elsif(check_sd_formatting($sdname)){
#			$status = $SD_STATUS_FORMATTING;
#		}elsif(check_sd_missing($sdname)){
#			$status = $SD_STATUS_MISSING;
#		}
#		if(exists $vol_status_info{$sdinfo[$i]{'volname'}}){
#			if($vol_status_info{$sdinfo[$i]{'volname'}} eq $SD_STATUS_CRITICAL || 
#				$vol_status_info{$sdinfo[$i]{'volname'}} eq $SD_STATUS_OFFLINE){
#				$status=$vol_status_info{$sdinfo[$i]{'volname'}};
#			}
#		}
		$sdinfo[$i]{"status"} = $status;

		# Assign UI actions: (remove "view", change "act_enable_protocol" to "act_share"
		my ($act_check, $act_extend, $act_delete, $act_mount, $act_share, $act_stop_check, $act_encrypt_setting,$act_rename) =
		   (0, 0, 0, 0, 0, 0, 0, 0, 0);
		if ($status eq $SD_STATUS_RECOVERYING) {
			# nothing
		}elsif($status eq $SD_STATUS_FORMATTING){
			# nothing
		}elsif ($status eq $SD_STATUS_CHECKING) {
			$act_stop_check = 1; 	# just only action "stop check" can show
		}elsif ($status eq $SD_STATUS_MISSING) {
			$act_delete=1;			# provide user to remove manaul
		}elsif ($status eq $SD_STATUS_OK) {
			$act_share = 1;
			$act_delete = 1;
			$act_rename = 1;
			
			$act_rename =0 if($sdinfo[$i]{'sdname'} eq $DEFAULT_HOMES_SDNAME);
			if ($sdinfo[$i]{'mounted'} == 0) {
				$act_mount = 1;
			}
			if ($sdinfo[$i]{'encrypted'} == 1 && $sdinfo[$i]{'mounted'} == 1 && $sdinfo[$i]{'type'} ne $SD_TYPE_SNAPSHOT) {
				$act_encrypt_setting = 1;
			}
			if ($sdinfo[$i]{'type'} eq $SD_TYPE_STANDARD ) {
				$act_check = 1;
				if ($sdinfo[$i]{'volfree'} >= $MIN_SD_REQUIRED_VOLFREE_MB ) {		#	UI minium unit is GB
					$act_extend = 1;
				}
			}
		}
		$sdinfo[$i]{'act_check'} = $act_check;
		$sdinfo[$i]{'act_extend'} = $act_extend;
		$sdinfo[$i]{'act_delete'} = $act_delete;
		$sdinfo[$i]{'act_mount'} = $act_mount;
		$sdinfo[$i]{'act_share'} = $act_share;
		$sdinfo[$i]{'act_stop_check'} = $act_stop_check;
		$sdinfo[$i]{'act_encrypt_setting'} = $act_encrypt_setting;
		$sdinfo[$i]{'act_rename'} = $act_rename;
		$sdinfo[$i]{'cluster_ip'} = $cluster_ip;
	}
	return @sdinfo;
}

########################################################################
#	input:	[ x	]
#	output:	[ hash data of ldid & device name]	("0"=>"sda" ,"3"=>"sdc")
########################################################################
sub get_ld_devmap{
	my $sys_path="/sys/class/scsi_device";
	opendir DIR , $sys_path;
	@allfiles = readdir DIR;
	%data=();

	foreach $file ( @allfiles ) {
		if ( $file ne "." && $file ne "..") {
			
			#modify rule for raid v402 rule
			my $ldid="";
			if ( $file =~ /(\d+):(\d+):(\d+):(\d+)/ ) {
				$ldid=$4;
				#print "get ldid:$ldid\n";
			}
			my $dev_path="$sys_path/$file/device";				# /sys/class/scsi_device/x:x:x:x/device
			if (-e $dev_path) {
				#print "cmd:realpath $dev_path\n";
				my $IN;
				open($IN,"$REALPATH_CMD $dev_path 2>/dev/null|");
					while(<$IN>) {
						if (index($_, "usb") != -1) {		#ignore usb path
							#print "usb path\n";			
							last;
						}else{
							my $IN2;
							open($IN2,"$REALPATH_CMD $sys_path/$file/device/block* 2>/dev/null |");	#ls -al /sys/class/scsi_device/1\:0\:0\:0/device/block*
							while(<$IN2>){
								if ( /\s*\/sys\/block\/(\S+)/ ) {					#/sys/block/sdc
									#print "ldid:$ldid,device:$1.\n";
									if($ldid ne "" && $1 ne ""){
										$data{$ldid}=$1;						
									}
								}
							}
							close($IN2)
						}
					}
				close($IN);
			} 
		}
	}
	closedir DIR;
	return %data;
}

########################################################################
#	input:	[ x	]
#	output:	[ hash data of df information]	HoH
#		{"c_vg5592-lv4855"=>{usage=>3,mount_on=>/FS/Backup,used=>259,available=>9980})
#		{"c_vg5592-lv2545"=>{usage=>3,mount_on=>/FS/Public,used=>259,available=>9980}}
########################################################################
sub get_df_info{
	my %data=();
	my %mount_info_hash=get_accept_mount_device();
	
	open(my $DF_IN,"$DF_CMD -m -P|");
	while(<$DF_IN>){
	    if(/(\S+:\/fsmnt\/[^\s]+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\%\s+(\/nasmnt\/[^\s]+)/){
			my $devname=$1;
			if(exists($mount_info_hash{$devname})){
#				print "data{$1} = {blocks =>$2,used =>$3 available =>$4 usage =>$5 mount_on =>$6}\n";
				$data{$1}={"blocks"=>$2,"used"=>$3,"available"=>$4,"usage"=>$5,"mount_on"=>$6};
			}
		}
	}
	close($DF_IN);
	
	return (\%data,\%mount_info_hash);
}
########################################################################
#	input:	[ x	]
#	output:	[ hash data of mount information]	hash
#		{"/dev/mapper/c_vg5592-lv4855"=>/FS/Public},
#		{"/dev/loop0"=>/ISO/ISOImage},
#		{"/dev/mapper/s_vg0179-lv6681TS1358180782ID001"=>/SNAPSHOT/StanderSD_14Jan2013_162622_001}
########################################################################
sub get_accept_mount_device{
	my %data=();
	open(my $MOUNT_IN,"$BUSYBOX_MOUNT_CMD |");
	while(<$MOUNT_IN>){
		if(/(\S+)\s+on\s+(\S+)\s+type\s+(\S+)/){
				$dev=$1;$mount=$2;$type=$3;	
				if($type eq "enfs"){
#					print "data{$dev} = $mount\n";
					$data{$dev}=$mount;
				}
		}
	}
	close($MOUNT_IN);
	return %data;
}

########################################################################
#	input:	[ x or vgname	]
#	output:	[ hash data of vgfree information]	Hash
#		{"c_vg5592"=>10210 ,"s_vg3434"=>9999)
########################################################################
sub get_vgfree_size{
	my ($arg_vgname)=@_;
	my %vgfree_info=();
	my $qry_vgname="";
	if(defined($arg_vgname)){
		$qry_vgname=$arg_vgname;
	}
	open(my $VGS_IN,"$VGS_CMD --noheadings --units m |");
	#vgs  c_vg0001   2   3   0 wz--nc 204792.00m  92152.00m
	#vgs  c_vg6744   1   0   0 wz--nc 953672.00m 953672.00m
	while(<$VGS_IN>){
		if(/.*\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\.\d*m\s+(\d+)\.\d*m/){
			if($qry_vgname eq ""){
				$vgfree_info{$1}=$7;
			}else{
				if( $qry_vgname eq $1 ){
					$vgfree_info{$1}=$7;
				}
			}
			
		}
		
	}
	close($VGS_IN);
	return %vgfree_info;
}	
#######################################################
#	Function to update fsck records
#		Parameter:		
#			sdname		sdname
#			start_time	start time  yyyy/mm/dd hh:mm:ss
#			stop_time	stop time	yyyy/mm/dd hh:mm:ss
#			last_status	0:ok , 1:fail
#			spend_time	ex. 1 d 2 h 3 m
#######################################################
sub update_fsck_log_record{
	my ($sdname,$start_time,$stop_time,$last_status,$spend_time)=@_;
	my %update_data;
	$update_data{'last_check_start_time'}=$start_time;
	$update_data{'last_check_stop_time'}=$stop_time;
	$update_data{'last_check_status'}=$last_status;
	$update_data{'last_check_spend_time'}=$spend_time;
	
	modify_sd_db($sdname,\%update_data);
}

#######################################################
#	Function to mark fs checking file which contains the running pid
#		parameter:	
#			isCluster 
#			sdname
#######################################################
sub mark_fs_checking{
	my ($isCluster,$sdname)=@_;
	my $pid=$$;
	my $fname="/tmp/".$sdname."_checking";
	system("echo $pid > $fname");
	#remote add , needless , take over will stop checking 
	#if($isCluster){
	#	SSHSystem("","echo $pid > $fname");
	#}
}
#######################################################
#	Function to remove fs checking file which contains the running pid
#		parameter:	
#			isCluster 
#			sdname
#######################################################
sub remove_fs_checking{
	my ($isCluster,$sdname)=@_;
	my $fname="/tmp/".$sdname."_checking";
	if(-e $fname){
		unlink($fname);
	}
	#remote remove
	#if($isCluster){
	#	SSHSystem("","$RM_CMD $fname");
	#}
}


#######################################################
#	Function to check sd is formatting or not
#	Output : 
#			1 ,is formatting
#			0 , not formatting
#######################################################
sub check_sd_formatting{
	my ($sdname)=@_;
	if($sdname ne ""){
		my $fname="/tmp/".$sdname."_formatting";
		if(-e $fname){
			return 1;
		}
	}
	return 0;
}
#######################################################
#	Function to check sd is formatting or not
#	Output : 
#			1 ,is formatting
#			0 , not formatting
#######################################################
sub check_sd_missing{
	my ($sdname)=@_;
	if($sdname ne ""){
		my $fname="/tmp/".$sdname."_missing";
		if(-e $fname){
			return 1;
		}
	}
	return 0;
}
#######################################################
#	Function to mark sd is missing or not
#	Output : 
#			None
#######################################################
sub mark_sd_missing{
	my ($sdname)=@_;
	my $pid=$$;
	my $fname="/tmp/".$sdname."_missing";
	system("echo $pid > $fname");
	return 0;
}
#######################################################
#	Function to check sd is fs checking or not
#	Output : 
#			1 ,is formatting
#			0 , not formatting
#######################################################
sub check_sd_checking{
	my ($sdname)=@_;
	if($sdname ne ""){
		my $fname="/tmp/".$sdname."_checking";
		if(-e $fname){
			return 1;
		}
	}
	return 0;
}
#######################################################
#	Function to add vol information to db
#######################################################
sub insert_db_volume_info{
	my ($insert_volname)=@_;
	my $vgname="",$volname="",$volsize=0,$vgsize=0,$vgfree=0,$raid_type="",$prefer_ctrlid="",$reserve_ratio="";
	my @vol_info=();
	
	open(my $VG_IN,"$VGS_INFO_CMD |");
	while(<$VG_IN>){
		if(/$VGS_PATTERN/){
			$vgname=$1;	$volsize=$2; $vgfree=$3; $raid_type=$4; $volname=$5;	$prefer_ctrlid=$6; $reserve_ratio=$7;
			# volsize = vgsize
			push @vol_info,{"vgname"=>$vgname,"volname"=>$volname,"volsize"=>$volsize,"vgfree"=>$vgfree,"raid_type"=>$raid_type,"prefer_ctrlid"=>$prefer_ctrlid,"reserve_ratio"=>$reserve_ratio};
		}
	}
	close($VG_IN);
	
	my $ret=0;
	for my $key ( @vol_info ) {
		if(defined($insert_volname)){
			#	insert specific
			if(	$key->{'volname'} eq $insert_volname){
				$volname=$key->{'volname'};
				$vgname=$key->{'vgname'};
				$vgsize=$key->{'volsize'};	#the same as vgsize
				$vgfree=$key->{'vgfree'};
				$raid_type=$key->{'raid_type'};
				$prefer_ctrlid=$key->{'prefer_ctrlid'};
				$reserve_ratio=$key->{'reserve_ratio'};
				$ret+=create_vol_db($volname,$raid_type,$prefer_ctrlid,$reserve_ratio,$vgname,$vgsize,$vgfree);
				last;
			}
		}else{
				#	insert all
				$volname=$key->{'volname'};
				$vgname=$key->{'vgname'};
				$vgsize=$key->{'volsize'};	#the same as vgsize
				$vgfree=$key->{'vgfree'};
				$raid_type=$key->{'raid_type'};
				$prefer_ctrlid=$key->{'prefer_ctrlid'};
				$reserve_ratio=$key->{'reserve_ratio'};
				$ret+=create_vol_db($volname,$raid_type,$prefer_ctrlid,$reserve_ratio,$vgname,$vgsize,$vgfree);
		}
	}
	return $ret;
}
#######################################################
#	Function to delete vol information in db
#######################################################
sub delete_db_volume_info{
	my ($del_volname)=@_;
	if(defined($del_volname)){
		#	delete specific
		delete_vol_db($del_volname);
	}else{
		#	delete all
		delete_vol_db();
	}
}
#######################################################
#	Function to update vol information to db
#######################################################
sub update_db_volume_info{
	my ($update_volname)=@_;
	my $vgname="",$volname="",$volsize=0,$vgsize=0,$vgfree=0,$raid_type="",$prefer_ctrlid="",$reserve_ratio="";
	my @vol_info=();
	
	open(my $VG_IN,"$VGS_INFO_CMD |");
	while(<$VG_IN>){
		if(/$VGS_PATTERN/){
			$vgname=$1;	$volsize=$2; $vgfree=$3; $raid_type=$4; $volname=$5; $prefer_ctrlid=$6; $reserve_ratio=$7;
			push @vol_info,{"vgname"=>$vgname,"volname"=>$volname,"volsize"=>$volsize,"volfree"=>$volfree,"vgfree"=>$vgfree,"raid_type"=>$raid_type,"prefer_ctrlid"=>$prefer_ctrlid,"reserve_ratio"=>$reserve_ratio};

		}
	}
	close($VG_IN);
	my %update_data;
	my $ret=0;
	if(!defined($update_volname)){
		$update_volname="";
	}
	for my $key ( @vol_info ) {
		if($update_volname eq "" || $update_volname eq $key->{'volname'} ){
			$update_data{'vgname'}=$key->{'vgname'};
			$update_data{'vgsize'}=$key->{'volsize'};	#the same as vgsize
			$update_data{'vgfree'}=$key->{'vgfree'};
			$update_data{'raid_type'}=$key->{'raid_type'};
			$update_data{'prefer_ctrlid'}=$key->{'prefer_ctrlid'};
			$update_data{'reserve_ratio'}=$key->{'reserve_ratio'};
			$ret+=modify_vol_db($key->{'volname'},\%update_data);
		}
	}
	return $ret;
}
#######################################################
#	Function to add SD information to db
#######################################################
sub insert_db_sharedisk_info{
	my ($volname,$sdname, $lvname, $lvsize, $type, $encrypted, $defperm, $smb_share, $afp_share, $ftp_share, $nfs_share, $webdav_share,$allow_ip_file)=@_;
	#my ($sdname, $volname, $lvname, $type, $encrypted, $perm, $smb_share, $afp_share, $ftp_share, $nfs_share, $webdav_share, $last_check_start_time, $last_check_stop_time, $last_check_status, $last_check_spend_time) = @_;
	create_sd_db($volname, $sdname, , $lvname, $lvsize, $type, $encrypted, $defperm, $smb_share, $afp_share, $ftp_share, $nfs_share, $webdav_share,'','',2,'',$allow_ip_file);
}	
########################################################
##	Function to update SD lvm information
########################################################
sub update_db_sharedisk_lvminfo{
	my ($update_sdname)=@_;
	my @sdinfo=();
	open(my $LVS_IN,"$LVS_INFO_CMD |");
	while(<$LVS_IN>){
		if( /$LVS_PATTERN1/ ||	/$LVS_PATTERN2/ || 	/$LVS_PATTERN3/ ){			
			my $vgname=$1;
			my $lvname=$2;	my $lvsize=$3;	
			my $attr=$4;	#ref http://www.tcpdump.com/kb/os/linux/lvm-attributes/intro.html
			my $encode_name=$5;
			my $sdname="";
			#my $encrypted=0;
			my $encrypt_tag=$6;
			
			if($encode_name ne ""){
				$sdname=`echo "$encode_name" | $BASE64_CMD -d`;
				chomp($sdname);
			}
			#if($encrypt_tag ne "" && ($encrypt_tag eq $SD_ENCRYPT_TAG)){
			#	$encrypted=1;
			#}
			push @sdinfo,{"sdname"=>$sdname,"lvsize"=>$lvsize,"vgname"=>$vgname,"lvname"=>$lvname};
		}
	}
	close($LVS_IN);
	
	my %update_data;
	if(!defined($update_sdname)){
		$update_sdname="";
	}
	for my $key ( @sdinfo ) {
		if($update_sdname eq "" || $update_sdname eq $key->{'sdname'} ){
			$update_data{'lvsize'}=$key->{'lvsize'};
			$update_data{'lvname'}=$key->{'lvname'};
			modify_sd_db($key->{'sdname'},\%update_data);
		}
	}
}
########################################################
#	Function to use current lvm information
#	to check & add missing sd(standard & hidden type) to db
########################################################
sub check_missing_sd_to_db{
	my ($arg_sync)=@_;
	my $no_sync_timestamp=0;
	if(defined($arg_sync)){
		$no_sync_timestamp=$arg_sync;
	}
	my @lvm_sdinfo=();
	my $ret=0;
	open(my $LVS_IN,"$LVS_INFO_CMD |");
	while(<$LVS_IN>){
		if( /$LVS_PATTERN1/ ||	/$LVS_PATTERN2/ || 	/$LVS_PATTERN3/ ){			
			my $vgname=$1;
			my $lvname=$2;	my $lvsize=$3;	
			my $attr=$4;	#ref http://www.tcpdump.com/kb/os/linux/lvm-attributes/intro.html
			my $encode_name=$5;
			my $sdname="";
			my $encrypted=0;
			my $encrypt_tag=$6;
			
			if($encode_name ne ""){
				$sdname=`echo "$encode_name" | $BASE64_CMD -d`;
				chomp($sdname);
			}
			if($encrypt_tag ne "" && ($encrypt_tag eq $SD_ENCRYPT_TAG)){
				$encrypted=1;
			}
			push @lvm_sdinfo,{"sdname"=>$sdname,"lvsize"=>$lvsize,"vgname"=>$vgname,"lvname"=>$lvname,"encrypted"=>$encrypted};
		}
	}
	close($LVS_IN);	
	my @sd_data=get_sdname_type_db();
	my @sdname_data=();
	for my $index(@sd_data){
		push @sdname_data,$index->{'sdname'};
	}
	my $sqlcmd="";
	for my $index(@lvm_sdinfo){
		if($index->{'sdname'} ne ""){
			if(check_sdname_exist(\@sdname_data,$index->{'sdname'})){
				#	update existed sd lvm information, needed ? slow
				#for my $key ( @lvm_sdinfo ) {
				#	$update_sdname=$index->{'sdname'};
				#	if($update_sdname eq $key->{'sdname'} ){
				#		$update_data{'lvsize'}=$key->{'lvsize'};
				#		$update_data{'lvname'}=$key->{'lvname'};
				#		modify_sd_db($key->{'sdname'},\%update_data);
				#	}
				#}
			}else{						
				#print "checking $index->{'sdname'}\n";
				#	in LVM but not in db , insert new records (only for hidden & standard)
				my $type='',$volname='';
				my $isHidden=0;
				if($index->{'sdname'} =~ m/$HIDDEN_SD_POSTFIX/){
					$isHidden=1;
				}
				my @vol_info=get_vol_info();
				for my $i(@vol_info){
					if($i->{'vgname'} eq $index->{'vgname'}){
						$volname=$i->{'volname'};
						last;
					}
				}
				$type=($isHidden==1)?$SD_TYPE_HIDDEN:$SD_TYPE_STANDARD;
		
				if( $volname ne "" && $index->{'sdname'} ne "" && $index->{'lvname'} ne ""){
					#$ret+=create_sd_db($volname,$index->{'sdname'},$index->{'lvname'}, $index->{'lvsize'}, $type, $index->{'encrypted'}, 0, 0, 0, 0, 0, 0,'','',2,'','') if($volname ne "");
					$sqlcmd .= "insert into SHARE_DISK (volname, sdname, lvname, lvsize, type, encrypted, defperm, smb_share, afp_share, ftp_share, nfs_share, webdav_share, last_check_start_time, last_check_stop_time, last_check_status, last_check_spend_time) values (";
					$sqlcmd .= "'$volname', '$index->{'sdname'}', '$index->{'lvname'}', $index->{'lvsize'}, '$type', $index->{'encrypted'}, $DEFAULT_SD_PERMISSION, $DEFAULT_ENABLE_SMB_VALUE, $DEFAULT_ENABLE_AFP_VALUE, $DEFAULT_ENABLE_FTP_VALUE, $DEFAULT_ENABLE_NFS_VALUE, $DEFAULT_ENABLE_WEBDAV_VALUE, '', '',$DEFAULT_SD_LAST_CHECK_STATUS, '');";
				}
			}
		}else{						#unknow or ISO or Snapshot
		}
	}
	if($sqlcmd ne ""){
		my $sqlfile = gen_random_filename("");
		open(my $OUT, ">$sqlfile");
		print $OUT "BEGIN TRANSACTION;\n";
		print $OUT "$sqlcmd\n";
		print $OUT "COMMIT;\n";
		close($OUT);
		$ret += exec_fs_sqlfile($sqlfile);
		unlink($sqlfile);
		
		# sync /nasdata/config/etc/fs.db
		SyncFileToRemote("", "$CONF_DB_FS",$no_sync_timestamp);
	}else{
		#print "nothing changed in db\n";
	}
	
	#	mark some Share Disk not in LVM but not in DB
	system("$RM_CMD /tmp/*_missing >/dev/null 2>&1");
	for my $index_sd(@sd_data) {
		my $found=0;
		for my $index_lv(@lvm_sdinfo){
			if($index_sd->{'sdname'} ne "" && $index_sd->{'sdname'} eq $index_lv->{'sdname'}){
				#print "$index_sd->{'sdname'} $index_sd->{'type'} \n";
				$found=1;
				last;
			}
		}
		mark_sd_missing($index_sd->{'sdname'}) if(!$found && $index_sd->{'type'} ne $SD_TYPE_ISO);
	} 
	return $ret;
}
###############################################################################
# 	Function to merge i2  array_id/array_alias , lds/ldalias  , pds information 
#		input: vol_info
#		output: merged i2 vol_info
###############################################################################
sub merge_vol_i2_info{
	my ($data_ref)=@_;
	my @vol_info=@$data_ref;
	
	my %dev_vg_hash=();
	my %ld_dev_hash=get_ld_devmap();					#("0"=>"sda" ,"3"=>"sdc")
	my %dev_ld_hash=reverse(%ld_dev_hash);
	my @array_info=get_i2_array_info();					#[1]->{"arrayid"=>1 , "pds"=>3,4,5 ,"lds"=>2,3,4 }
	open(my $PVS_IN,"$PVS_CMD --noheadings -o pv_name,vg_name |");
		while(<$PVS_IN>){
			#pvs  /dev/sdc   c_vg5592
			if(/pvs\s+\/dev\/(\S+)\s+(\S+)/){
				$dev_vg_hash{$1}=$2;				#("sda"=>"c_vg1234","sdc"=>"s_vg9999")
			}
			
		}
	close($PVS_IN);

	foreach my $index(@vol_info){
		my $search_vgname=$index->{'vgname'};
		my @arrayid=(),@array_alias=(),@lds=(),@ldalias=(),@pds=(),@ldstatus=();
		while(my($devname,$vgname)=each(%dev_vg_hash)){		#one volume may contain multiple lds
			if($search_vgname eq $vgname){					#find devname
				if(exists($dev_ld_hash{$devname})){			#find ld number
					my $search_ld=$dev_ld_hash{$devname};
					foreach my $ary_index(@array_info){
						my @search_lds=split(/,/, $ary_index->{'lds'});
						my @search_ldalias=split(/,/, $ary_index->{'ldalias'});
						my @search_ldstatus=split(/,/, $ary_index->{'ldstatus'});
						for (my $i=0; $i<=$#search_lds; $i++) {
							if($search_ld eq $search_lds[$i]){
								push @arrayid,$ary_index->{'arrayid'};
								push @array_alias,$ary_index->{'array_alias'};
								push @pds,$ary_index->{'pds'};
								push @lds,$search_lds[$i];
								push @ldalias,$search_ldalias[$i];
								push @ldstatus,$search_ldstatus[$i];

							}
						}
					}
				}
			}
		}
		$index->{'arrayid'}=join(',', @arrayid);
		$index->{'array_alias'}=join(',', @array_alias);
		$index->{'pds'}=join(',', @pds);
		$index->{'lds'}=join(',', @lds);
		$index->{'ldalias'}=join(',', @ldalias);
		$index->{'ldstatus'}=join(',', @ldstatus);
	}
}

######################################################
# 	Function to get array id & pd map
#			ex. [0]->{"arrayid"=>0 "array_alias"=>NASAry_alais1, "pds"=>1,2 , "lds"=>0 ,"ldalias"=>"NASLD"}
#				[1]->{"arrayid"=>1 ,"array_alias"=>NASAry_alais2, "pds"=>3,4,5 ,"lds"=>2,3,4 , "ldalias"=>"NASLD2,NASLD3,NASLD4" }
######################################################
sub get_i2_array_info{
	my @data=();
	open(my $I2_IN,"$I2ARYTOOL_CMD array  -v |");
	my $arrayid="",$array_alias="",@pds=(),@lds=(),@ldalias=(),@ldstatus=(),$pd_area=0,$ld_area=0,$pd_str="",$ld_str="",$ld_alias_str="",$ld_status_str="";
	while(<$I2_IN>){
		if(/^DaId:\s+(\S+)/){
			$arrayid=$1;
		}elsif(/^Alias:\s+(\S+)/){
			$array_alias=$1;
		}elsif(/Physical Drives in the Array:/){
			$pd_area=1;
			$ld_area=0;
		}elsif(/Logical Drives in the Array:/){
			$pd_area=0;
			$ld_area=1;
		}
		if($pd_area){
			if(/^\d+\s+(\d+)\s+/){
				push(@pds,$1)
			}
			if(/^\s*$/){			#blank line , pd_area finished
				$pd_str=join(',', @pds);
				$pd_area=0;
			}
		}
		if($ld_area){
			if(/^(\d+)\s+(\S*)\s+RAID\S+\s+(\d*\.\d*)\s+(\S*B)\s+(\S+)/){
				push(@lds,$1);
				push(@ldalias,$2);
				push(@ldstatus,$5);
			}
			if(/^\s*$/){			#blank line , ld_area finished
				$ld_str=join(',', @lds);
				$ld_alias_str=join(',', @ldalias);
				$ld_status_str=join(',',@ldstatus);
				if($arrayid ne ""){
					push @data,{"arrayid"=>$arrayid,"array_alias"=>$array_alias,"pds"=>$pd_str,"lds"=>$ld_str,"ldalias"=>$ld_alias_str,"ldstatus"=>$ld_status_str};
				}
				#init 
				$arrayid="",$array_alias="",@pds=(),@lds=(),@ldalias=(),@ldstatus=(),$pd_area=0,$ld_area=0,$pd_str="",$ld_str="",$ld_alias_str="",$ld_status_str="";
			}
		}
	}
	close($I2_IN);
	return @data;
}
########################################################################
#  input: X
#  output: $res: 0=OK, 1=Fail
#  desc: flush VOLUME TABLE INFORMATION
#  example: flush_db_volume_info();
########################################################################
sub flush_db_volume_info{
	my ($arg_sync)=@_;
	my $no_sync_timestamp=0;
	if(defined($arg_sync)){
		$no_sync_timestamp=$arg_sync;
	}

	#	Collect lvm information
	my $vgname="",$volname="",$vgsize=0,$vgfree=0,$raid_type="",$prefer_ctrlid="",$reserve_ratio="";
	my @vol_info=();
	open(my $VG_IN,"$VGS_INFO_CMD |");
	while(<$VG_IN>){
		if(/$VGS_PATTERN/){
			$vgname=$1;	$vgsize=$2; $vgfree=$3; $raid_type=$4; $volname=$5;	$prefer_ctrlid=$6; $reserve_ratio=$7;
			push @vol_info,{"vgname"=>$vgname,"volname"=>$volname,"vgsize"=>$vgsize,"vgfree"=>$vgfree,"raid_type"=>$raid_type,"prefer_ctrlid"=>$prefer_ctrlid,"reserve_ratio"=>$reserve_ratio};
		}
	}
	close($VG_IN);
	my $sqlfile = gen_random_filename("");
	my $sqlcmd="";
	open(my $OUT, ">$sqlfile");
	print $OUT "BEGIN TRANSACTION;\n";
	print $OUT "delete from VOLUME;\n";
	for my $key ( @vol_info ) {
		$volname=$key->{'volname'};
		$vgname=$key->{'vgname'};
		$vgsize=$key->{'vgsize'};	#the same as vgsize
		$vgfree=$key->{'vgfree'};
		$raid_type=$key->{'raid_type'};
		$prefer_ctrlid=$key->{'prefer_ctrlid'};
		$reserve_ratio=$key->{'reserve_ratio'};
		$sqlcmd = "insert into VOLUME (volname, raid_type, prefer_ctrlid, reserve_ratio, vgname, vgsize, vgfree) values (";
		$sqlcmd .= "'$volname', '$raid_type', $prefer_ctrlid, $reserve_ratio, '$vgname', $vgsize, $vgfree)";
		print $OUT "$sqlcmd;\n";
	}
	print $OUT "COMMIT;\n";
	close($OUT);
	my $dbres=exec_fs_sqlfile($sqlfile);
	unlink($sqlfile);
	
	# sync /nasdata/config/etc/fs.db
	SyncFileToRemote("", "$CONF_DB_FS",$no_sync_timestamp);
	return $dbres;
}
########################################################################
#  input: sdname array,check sdname
#  output: 0:not existed ,1:existed
#  desc: check sdname existed or not (on-fly array check without check db everytime)
#  example: check_sdname_exist(\@sdnameAry,"sdname");
########################################################################
sub check_sdname_exist{
	my ($data_ref,$sdname)=@_;
	my @data=@$data_ref;
	foreach(@data){
		if($_ eq $sdname){
			return 1;
		}
	}
	return 0;
}
################################################
#	Get Volume(Disk Pool) status hash map
#	input:	[X]
#	output:	{'D1'=>'OK','D2'=>'Critical'}
################################################
sub get_vol_status_map{
	my @volinfo=get_vol_info();
	my %data=();
	for my $index(@volinfo){
		$data{$index->{'volname'}}=$index->{'status'};
	}
	return %data;
}
################################################
#	When add Helios mount point, auto add share folder.
#	input:	[folder]
#	output:	{0}
################################################
sub CheckHeliosfolder{
	my ($localmount) = @_;
	my $num=$heliosip=$mountpoint=$volname="";
	open(IN,"/nasdata/config/etc/helios.conf");
	while(<IN>){
		if(/\[(\d+)\]/){
			$num=$1;
		}elsif(/HELIOSIP=(\S+)/){
			$heliosip = $1;
		}elsif(/HELIOSMOUNT=(.+)/){
			$mountpoint = $1;
		}elsif(/LOCALMOUNT=(.+)/){
			if($localmount eq $1){
				$volname = "$heliosip:$mountpoint";
			}
		}
	}
	close(IN);
my @folder = {};
my $i = 0;
my $dir = $localmount;
$dir =~ s/\/nasmnt\///g;
my @sdinfo=get_share_disk_info($dir);
@sdinfo = grep { $_->{'type'} ne $SD_TYPE_HIDDEN } @sdinfo;
if ($#sdinfo == -1){
	 insert_db_sharedisk_info($volname, $dir, $localmount, 0,'enfs', 0, $DEFAULT_SD_PERMISSION, $DEFAULT_ENABLE_SMB_VALUE, $DEFAULT_ENABLE_AFP_VALUE, $DEFAULT_ENABLE_FTP_VALUE, $DEFAULT_ENABLE_NFS_VALUE, $DEFAULT_ENABLE_WEBDAV_VALUE,"");
}
	return 0;
}
################################################
#	When umount Helios mount point, auto umount share folder.
#	input:	[folder]
#	output:	{0}
################################################
sub DeleteHeliosfolder{
	my ($localmount) = @_;
	my $num=$heliosip=$mountpoint=$volname="";
	open(IN,"/nasdata/config/etc/helios.conf");
	while(<IN>){
		if(/\[(\d+)\]/){
			$num=$1;
		}elsif(/HELIOSIP=(\S+)/){
			$heliosip = $1;
		}elsif(/HELIOSMOUNT=(.+)/){
			$mountpoint = $1;
		}elsif(/LOCALMOUNT=(.+)/){
			if($localmount eq $1){
				$volname = "$heliosip:$mountpoint";
			}
		}
	}
	close(IN);
	my @folder = {};
	my $i = 0;
	my $dir = $localmount;
	$dir =~ s/\/nasmnt\///g;
			my @sdinfo=get_share_disk_info($dir);
			@sdinfo = grep { $_->{'type'} ne $SD_TYPE_HIDDEN } @sdinfo;
			if ($#sdinfo != -1){
#					print_AOH(\@sdinfo);
					delete_sd_db($dir);
			}	
	return 0;

}


sub set_heliosconf{
	my (@hpoint)=@_;
	
	my $file = gen_random_filename("");
	open(my $OUT, ">$file");	
	$num = 0;
	foreach $point(@hpoint){
#		print $point->{"HELIOSIP"} .  "\n";
		print $OUT "[$num]\n";
		print $OUT "HELIOSIP=" . $point->{"HELIOSIP"} . "\n";
		print $OUT "HELIOSMOUNT=" . $point->{"HELIOSMOUNT"} . "\n";
		print $OUT "LOCALMOUNT=" . $point->{"LOCALMOUNT"} . "\n";
		print $OUT "OPTION=" .  $point->{"OPTION"} . "\n";
		$num ++;
	}
	close($OUT);
	copy_file_to_realpath($file, "/nasdata/config/etc/helios.conf");
	unlink($file);	
}

sub getdf{
	my @hpoint = ();
	my $retry = 0;
	while($retry < 5){
		if(!-f "/tmp/df_lock"){
			system("touch /tmp/df_lock");
			open(my $IN,"df -P 2>&1|");
			while(<$IN>){
#    if(/(\S+):(\/\S+\/[^\/]+\S)\s+\d+\s+\d+\s+\d+\s+\d+\%\s+(\/\S+)/){
				if(/(\S+):(\/fsmnt\/[^\s]+)\s+\d+\s+\d+\s+\d+\s+\d+\%\s+(\/nasmnt\/[^\s]+)/){
					my $ip=$1;
					my $hmnt=$2;
					my $lmnt=$3;
					push @hpoint,{"HELIOSIP"=>$ip,"HELIOSMOUNT" => $hmnt,"LOCALMOUNT" => $lmnt};
				}elsif(/df:\s+(.+):/){
					my $lmnt=$1;
					push @hpoint,{"HELIOSIP"=>"","HELIOSMOUNT" =>"" ,"LOCALMOUNT" => $lmnt};
				}
			}
			close($IN);
			unlink("/tmp/df_lock");
			return @hpoint;
		}else{
			sleep(1);
			$retry++;
		}
	}
	return @hpoint;
}


sub get_helios_mountinfo{   #hanly.chen 2013/08/19   get helios mount info

my @heliosmntinfo =();
my @hpoint = ();
my $num = 0;
@hpoint = getdf(); 



open(IN,"$HELIOS_CONF");
my $heliosip;
my $mountpoint;
my $localmount;
my $mounted;
my $option;
while(<IN>){
	if(/\[(\d+)\]/){
	
	}elsif(/HELIOSIP=(\S+)/){
		$heliosip=$1;
	}elsif(/HELIOSMOUNT=(.+)/){
		$mountpoint=$1;
	}elsif(/LOCALMOUNT=(.+)/){
		$localmount=$1;
	}elsif(/OPTION=(\d+)/){
		$option = $1;
		$mounted = 0;
		foreach my $point(@hpoint){
#		if($point eq "$heliosip:$mountpoint"){
			if($point->{"HELIOSIP"} eq $heliosip && $point->{"HELIOSMOUNT"} eq $mountpoint && $point->{"LOCALMOUNT"} eq $localmount ){
					$mounted = 1;
			}elsif($point->{"HELIOSIP"} eq "" && $point->{"HELIOSMOUNT"} eq "" && $point->{"LOCALMOUNT"} eq $localmount){
					$mounted = 2;
			}
		}
		if($mounted == 0 ){
			open($IN,"mount |");
			while(<$IN>){
			if(/(\S+):([^\s]+)\s+on\s+(\/nasmnt\/[^\s]+)\s+type\s+enfs/){
				my $ip=$1;
				my $hmnt=$2;
				my $lmnt=$3;
				print "$heliosip eq $ip && $mountpoint eq $hmnt && $localmount eq $lmnt\n";
				if($heliosip eq $ip && $mountpoint eq $hmnt && $localmount eq $lmnt){
					$mounted=2;
				}
			}
			}
			close($IN);	
		}
		push @heliosmntinfo,{"HELIOSIP" => $heliosip ,"HELIOSMOUNT" => $mountpoint,"LOCALMOUNT" => $localmount , "mounted" => "$mounted","OPTION" =>"$option"};		
#		print "$heliosip $mountpoint $localmount\n";	
	}	
}
close(IN);

	return @heliosmntinfo;

}
sub clear_helios_config{  #hanly.chen add clear helios config and db 2013/08/19
	my @heliosmntinfo = ();
	@heliosmntinfo = get_helios_mountinfo();
	foreach my $mntinfo(@heliosmntinfo){
			if($mntinfo->{'mounted'} == 1){
				return -1;
			}	
	}
	system("echo \"\" > $HELIOS_CONF");
	system("echo \"no\" > /etc/server/smb");
	system("echo \"no\" > /etc/server/nfs");
	system("echo \"no\" > /etc/server/keepalived");
	system("echo 0 > /nasdata/config/etc/permissionId.conf");
	system("echo \"\" > /nasdata/config/etc/permissionsync.conf");
	system("echo 0 > /nasdata/config/etc/timestamp");
	system("rm /nasdata/config/etc/user.db");
	system("rm /nasdata/config/etc/fs.db");
#	system("rm /nasdata/config/etc/*.db");
	system("/nasapp/perl/util/db_create_db.pl acc");
	system("/nasapp/perl/util/db_create_db.pl fs");
	system("rm /nasdata/config/etc/eventidx");
	mark_reload_protocol("ALL");
	return 0;
}
sub renamemountpoint{
	my($newmnt,$oldmnt)=@_;
	
	my $new_name = $newmnt;
	my $old_name = $oldmnt;
	$new_name =~ s/\/nasmnt\///g;
	$old_name =~ s/\/nasmnt\///g;

#print "$new_name $newmnt $old_name  $oldmnt \n";
##########	update fs.db	(SHARE_DISK,NFS_ALLOW_IP)	##########
	my $sqlfile = gen_random_filename("");
	open(my $OUT, ">$sqlfile");
	print $OUT "BEGIN TRANSACTION;\n";
	print $OUT "update SHARE_DISK set sdname='$new_name',lvname='$newmnt' where sdname = '$old_name';\n";
	print $OUT "COMMIT;\n";
	print $OUT "BEGIN TRANSACTION;\n";
	print $OUT "update NFS_ALLOW_IP set sdname='$new_name' where sdname = '$old_name';\n";
	print $OUT "COMMIT;\n";
	close($OUT);
	my $dbres=exec_fs_sqlfile($sqlfile);
	unlink($sqlfile);

	if($dbres !=0){
		naslog($LOG_FS_SHAREDISK,$LOG_ERROR,86,"Rename Share Folder [$old_name] for filesystem failed.");
	}

##########	update user.db	(PERMISSION,PERM_UNSET,QUOTA,QUOTA_UNSET)	##########
	$sqlfile = gen_random_filename("");
	open(my $OUT, ">$sqlfile");
	print $OUT "BEGIN TRANSACTION;\n";
	print $OUT "update PERMISSION set sdname='$new_name' where sdname = '$old_name';\n";
	print $OUT "COMMIT;\n";
	print $OUT "BEGIN TRANSACTION;\n";
	print $OUT "update PERM_UNSET set sdname='$new_name' where sdname = '$old_name';\n";
	print $OUT "COMMIT;\n";
	close($OUT);
	$dbres=exec_acc_sqlfile($sqlfile);
	unlink($sqlfile);

	if($dbres !=0){
		naslog($LOG_FS_SHAREDISK,$LOG_ERROR,87,"Rename Share Folder [$old_name] for account failed.");
	}
#	mark reload
	mark_reload_protocol("ALL");
	naslog($LOG_FS_SHAREDISK,$LOG_INFORMATION,80,"Rename Share Folder [$old_name] successfully.");
}

sub umountHeliosall{
	my  @hpoint = ();
	@hpoint  = get_helios_mountinfo();
    my  $result = 0;

	foreach my $point(@hpoint){
		my $localmount = $point->{"LOCALMOUNT"};
		Disablesharefolder($localmount);
	}
    mark_reload_protocol("ALL");
    waitreload();
	foreach my $point(@hpoint){
		my $connected = $point->{"mounted"};
		my $heliosip = $point->{"HELIOSIP"};
		my $mountpoint = $point->{"HELIOSMOUNT"};
		my $localmount = $point->{"LOCALMOUNT"};
		my $ret = 0;
		my $Errorlog = "";
		if($connected ==1 || $connected == 2){
			enfsumount($localmount);	
			$ret = $result[0]->{'result'};
			$Errorlog = $result[0]->{'Errorlog'};
		}
		if($ret == 0){
		    DeleteHeliosfolder("$localmount");
		    mark_reload_protocol("ALL");
			naslog($LOG_NAS_MOUNT,$LOG_INFORMATION,"01","Unmount $heliosip:$mountpoint from  $localmount successfully");
		}else{
			naslog($LOG_NAS_MOUNT,$LOG_ERROR,"01","Unmount $localmount $Errorlog");
			naslog($LOG_NAS_MOUNT,$LOG_ERROR,"01","Unmount $heliosip:$mountpoint from  $localmount unsuccessfully");
			$result =  1;
		}	
	}
	@mpoint = ();
	set_heliosconf(@mpoint);
	return $result;
}

sub enfsmount
{
	my ($remotemount,$localmount,$option) = @_;
	my $Errorlog="";
	my $connected = 0;
	my $IN = "";
#	CheckMultipath();
	if(!-d $localmount){
		system("mkdir \"$localmount\"");
	}
	if($option == 0){
		open($IN,"mount.enfs \"$remotemount\" \"$localmount\" -o ro,hard,nolock,quick_list,actimeo=1,timeo=60,intr 2>&1|");
	}elsif($option == 1){
		open($IN,"mount.enfs \"$remotemount\" \"$localmount\" -o rw,hard,nolock,quick_list,actimeo=1,timeo=60,intr 2>&1|");
	}
	while(<$IN>){
			print "***************** $_";
			if(/QIconvCodec/){
			}else{
				chomp($_);
				$Errorlog = $Errorlog . $_;
			}	
	}
	close($IN);
	if($Errorlog ne ""){
		 $Errorlog =~ s/[\(\)\"]//g;
	     naslog($LOG_NAS_MOUNT,$LOG_ERROR,"02","$Errorlog");
	}
	open($IN,"mount |");
	while(<$IN>){
		if(/(\S+):([^\s]+)\s+on\s+(\/nasmnt\/[^\s]+)\s+type\s+enfs/){
			my $ip=$1;
			my $hmnt=$2;
			my $lmnt=$3;
			if($remotemount eq "$ip:$hmnt" && $localmount eq $lmnt){
				$connected = 1;
			}
		}

	}
	close($IN);	
#if option equal to 2, mean that I don't want to mount it,
#So check connect wouldn't find this mount,
#So switch it.
	if($option == 2){
		if($connected == 1){
			$connected = 0;
		}else{
			$connected = 1;
		}
	}

	my @cresult = ();
	push @cresult,{"connected" => $connected,"Errorlog" => $Errorlog};
	return @cresult;
}
sub enfsumount{
	my($localmount)=@_;
	my $retry =0;
	my $ret = 1;

	while($ret == 1 && $retry < 10){
		$ret = 0;
		print "2 Umount ret = $ret\n";
	    kill_all_accessing_process($localmount);	
		open(IN,"umount.enfs $localmount -f 2>&1 |");
		while(<IN>){
			print "$_";
			if(/QIconvCodec/){
			}else{
				$ret = 1;		
				$Errorlog = $Errorlog . $_ . "\n";
				print "$Errorlog\n";
			}	
		}
		close(IN);
		$retry++;
		if($retry > 1 && $ret == 1){
			sleep 1;
		}
	}
	if($ret == 0){	
		system("rmdir $localmount");
	}
	my @cresult = ();
	push @cresult,{"result" =>$ret,"Errorlog" => $Errorlog};
	return @cresult;
}

sub after_ChangeHeliosIP{
	@mountinfo = ();
	@mountinfo  = get_helios_mountinfo();
	system("/etc/init.d/enfs start");
	foreach $mount(@mountinfo){
			print $mount->{'mounted'} . " \n";
					$remotemount = $mount->{'HELIOSIP'} . ":" .  $mount->{'HELIOSMOUNT'};
					@res = ();
					@res = enfsmount($remotemount,$mount->{'LOCALMOUNT'},$mount->{'OPTION'});
	}
	return 0;
}
sub before_ChangeHeliosIP{
#	my ($oldip,$newip) = @_;
	my ($newip) = @_;
	if($newip eq "") {#Get the current A-Class IP if newip is null.
		my $join_info = `cat /nasdata/config/etc/join_info.conf`;
		if($join_info =~ /HELIOS_JOIN\=(\d+\.\d+\.\d+\.\d+)/) {
			$newip = $1;
		} else {
			return 0;
		}
	}
	my @data=();
	my $ret = 0;

 	my  @hpoint = ();
	@hpoint  = get_helios_mountinfo();
    foreach my $point(@hpoint){
        my $localmount = $point->{"LOCALMOUNT"};
        Disablesharefolder($localmount);
    }
    mark_reload_protocol("ALL");
    waitreload();


	@data  = get_helios_mountinfo();
	foreach my $point(@data){
			my $localmount = $point->{'LOCALMOUNT'};
			my $heliosip =$point->{'HELIOSIP'};
			my $mounted  = $point->{'mounted'};
			if($mounted != 0){
				enfsumount($localmount);		
			}
	}
	foreach my $mount(@data){
				$mount->{'HELIOSIP'} = $newip;
	}
	set_heliosconf(@data);
	my %update_data;
	my @sdinfo=get_share_disk_info();
	for my $index ( @sdinfo ) {
		if($index->{'volname'} =~ /(\S+):(\S+)/){
				$update_data{'volname'}="$newip:$2";
				modify_sd_db($index->{'sdname'},\%update_data);
		}
	}
	return $ret;
}
sub waitreload{
	$waitcount = 0;
	system("ls -l /etc/server/");
    while(1){
		if(!-f "/etc/server/reload.all" || $waitcount > 15){
			system("ls -l /etc/server/");
			return 0;
		}
		$waitcount++;
		sleep 1;
		print "waitreload\n";	
	}
}
sub getsharefolder{
	my($localmount)=@_;
	my $dir = $localmount;
	$dir =~ s/\/nasmnt\///g;
	my @sdshare = get_sdname_share($dir);
	if ($#sdshare != -1){
		return @sdshare;
	}
	return @sdshare;		
}
sub Disablesharefolder{
	my($localmount)=@_;
	my $dir = $localmount;
	$dir =~ s/\/nasmnt\///g;
	my %update_data;
	$update_data{'smb_share'}=0;
	$update_data{'afp_share'}=0;
	$update_data{'ftp_share'}=0;
	$update_data{'nfs_share'}=0;
	$update_data{'webdav_share'}=0;
	modify_sd_db($dir,\%update_data);
}
sub enablesharefolder{
	my($localmount,@sdshare)=@_;
	my $dir = $localmount;
	$dir =~ s/\/nasmnt\///g;
	my %update_data;
	$update_data{'smb_share'}=$sdshare[0]->{'smb_share'};
	$update_data{'afp_share'}=$sdshare[0]->{'afp_share'};
	$update_data{'ftp_share'}=$sdshare[0]->{'ftp_share'};
	$update_data{'nfs_share'}=$sdshare[0]->{'nfs_share'};
	$update_data{'webdav_share'}=$sdshare[0]->{'webdav_share'};
	modify_sd_db($dir,\%update_data);
}
sub CheckMultipath{
my $timeout=300;
my $check = 0;
while($timeout > 0 && $check==0){
	$check=0;
	my @scsiary = ();
	opendir ( DIR, "/sys/class/scsi_device/" ) || die "Error in opening dir /sys/class/scsi_device/\n";
	while( (my $filename = readdir(DIR))){
		if($filename =~/(\d+)\:(\d+)\:(\d+)\:(\d+)/){ 
			if($1 == 6 || $1 == 7){ 
				push @scsiary,{"scsi" => "$filename", "find" => 0};
				  print("$filename\n");
			}
		}
	}
	closedir(DIR);

	system("multipath -r");
	open(IN,"multipath -l|");
	while(<IN>){
		if(/(\d+\:\d+\:\d+\:\d+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+/){
			my $scsi = $1;
			foreach my $dev(@scsiary){
				if($dev->{"scsi"} eq $scsi){
					$dev->{"find"} = 1;
				}
			}
			print "$1\n";
		}
	}
	close(IN);
	foreach $dev(@scsiary){
		if($dev->{"find"} == 0){
			print $dev->{"scsi"} . "\n";
			$check=1;	
		}
	}
	sleep 1;
}



}

return 1;  # this is required.
