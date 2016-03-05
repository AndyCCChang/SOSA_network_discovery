#!/usr/bin/perl
#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: pro_smb_lib.pl
#  Author: Paul Chang
#  Modify: Olive Huang
#  Date: 2012/12/12
#  Description:
#    Functions to modify samba config file.
#########################################################################

require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/pro_lib.pl";
require "/nasapp/perl/lib/fs_lib.pl";

#########################################################
#  Set samba settings(computer name, computer description).
#  Input:   computer_name   setting computer name(string)
#           description     setting samba server description(string)
#  Output:  0=OK
#  Example: setsmbconfig(promise, promise_server);
#########################################################
sub setsmbconfig {
#	my($computer_name, $description) = @_;
	my($description,$new_option) = @_;
	my($origin_smb, $smbtmp);
	my $old_option = -1;
    open(my $IN, "cat $SMB_OPTION 2>/dev/null |");
	    while(<$IN>) {
	        if ( /Current\s+Option=(\d+)/ ) {
	            $old_option = $1;
				print "old_option = $old_option new_option = $new_option\n";
	            last;
			}
	    }
	close($IN);

	#Minging.Tsai. 2014/5/14. Add the protection if smboption goes null.
	if(`cat $SMB_OPTION` eq "" || $old_option eq -1) {
	    print "The original $SMB_OPTION is somehow null. Restore it.\n";
		system("cp /tmp/nasdata_src/config/etc/smboption.src $SMB_OPTION");
		if($new_option == 0){
			$old_option = 11;
		}else{
			$old_option = 0;
		}
																							                   
	}

	my $is_diff = 0;
	if($new_option != $old_option && $new_option ne ""){
	     $is_diff = 1;
	}

	# write new config into smb.conf
	$origin_smb = gen_random_filename("$SMB_CONF");
	$smbtmp = gen_random_filename("$SMB_CONF");
	system("$CP_CMD -f $SMB_CONF $origin_smb");
	open(my $OUT, ">$smbtmp");
	open(my $IN, "<$origin_smb");
    if($is_diff){
        my @add_str, @del_str;
        my $i = 0;
        my $j = 0;
        my $remove = 0;
        my $add = 0;

        open(my $OPT, "<$SMB_OPTION");
        while (<$OPT>) {
			print "$_";
			$str = $_;
			chomp $str;

			if ($str eq $old_option){
			    $remove = 1;
			    next;
			}
			if ($str eq $new_option){
			    $add = 1;
			    next;
			}
			if($remove && ($str ne "======================")){
				print "delstr str: $str\n";
				$del_str[$i] = "\t$str";
				$i++;
			}
			elsif($remove && ($str eq "======================")){
			    $remove = 0;
			}
			if($add && ($str ne "======================")){
			    print "addstr str: $str\n";
			    $add_str[$j] = $str;
			    $j++;
			}
			elsif($add && ($str eq "======================")){
			    $add = 0;
			}
		}	
		close($OPT);

		while (<$IN>) {
		    my $do_remove = 0;
		    for($i=0; $i<=$#del_str; $i++) {
		        $instr = $_;
		        chomp $instr;
		        if($instr eq $del_str[$i]){
		             print "rm $del_str[$i]\n";
		             $do_remove = 1;
		             last;
		        }
		    }

			if($do_remove)
			{
			    next;
			}

			if (/^#/ || /^;/) {
				print $OUT "$_";
            }
			elsif (/server\s+string\s+\=\s+(.*)/) {
				if($description ne ""){
					print $OUT "	server string = $description\n";
				}
				else{
					print $OUT "$_";
			    }
			}
		    #add new option
            elsif ( /security/ ){
				print $OUT "$_";
                for($i=0; $i<=$#add_str; $i++) {
	                print $OUT "\t$add_str[$i]\n";
		        }
            }else {
                print $OUT "$_";
            }


            my $outtmpfile = gen_random_filename("$SMB_OPTION");
            my $intmpfile = gen_random_filename("$SMB_OPTION");
            system("$CP_CMD -f $SMB_OPTION $intmpfile");
            open(my $INOP, "<$intmpfile");
            open(my $OUTOP, ">$outtmpfile");
            while (<$INOP>) {
				if ( /Current\s+Option=(\d+)/ ) {
					print $OUTOP "Current Option=$new_option\n";
				}
				else{
					print $OUTOP "$_";
				}
            }
			close($OUTOP);
			close($INOP);
			system("$CP_CMD -f $outtmpfile $SMB_OPTION");
			unlink("$outtmpfile");
			unlink("$intmpfile");
		}
    }
	else{#only change computer name or description
		while (<$IN>) {
			if (/^#/ || /^;/) {
				print $OUT "$_";
			}
#			elsif (/netbios\s+name\s+\=\s+(.*)/) {
#				print $OUT "	netbios name = $computer_name\n";
#			}
			elsif (/server\s+string\s+\=\s+(.*)/) {
				print $OUT "	server string = $description\n";
			}
			else {
				print $OUT "$_";
			}
		}
	}
	close($IN);
	close($OUT);
	
	copy_file_to_realpath($smbtmp, $SMB_CONF);
	unlink($origin_smb);
	unlink($smbtmp);

	#Minging.Tsai. 2014/12/5. Don't reload protocol here.
	# reload config
	#mark_reload_protocol("SMB");
	#mark_reload_protocol("FTP");

	#mark_reload_protocol("AFP");

	return 0;
}

#########################################################
#  Get samba settings(computer name, workgroup name, computer description).
#  Input:   -
#  Output:  a hash contains information with keys {computer_name, workgroup, description}
#  Example: getsmbconfig();
#########################################################
sub getsmbconfig {
	my $wg      = "";
	my $nname   = "";
	my $sstring = "";
	my %result;
	my $smb_option = 0;
		
	open(my $IN, "cat $SMB_OPTION 2>/dev/null |");
	while(<$IN>) {
		if ( /Current\s+Option=(\d+)/ ) {
			$smb_option = $1;
			last;
		}
	}
	close($IN);

	my $origin_smb = gen_random_filename("$SMB_CONF");
	system("$CP_CMD -f $SMB_CONF $origin_smb");
	open (my $IN, "<$origin_smb");
	while (<$IN>) {
		#ignore config comment
		if (/^#/ || /^;/) {
			next;
		}
	
		if (/workgroup\s+\=\s+(.*)/) {
			$wg = $1;
			chomp($wg);
		}
		elsif (/netbios\s+name\s+\=\s+(.*)/) {
			$nname = $1;
			chomp($nname);
		}
		elsif (/server\s+string\s+\=\s+(.*)/) {
			$sstring = $1;
			chomp($sstring);
		}
	# client code page(text encoding), no use now?
	#elsif (/client\s+code\s+page\s+\=\s+(\S*)/) {
	#	$ccpage = $1;
	#	chomp($ccpage);
	#}
	}
	close($IN);
	unlink($origin_smb);
	
	$result{"computer_name"} = $nname;
	$result{"workgroup"}     = $wg;
	$result{"description"}   = $sstring;
	$result{"smboption"}	 = $smb_option;

	return %result;
}

###########################################################
#  Get samba permission string
#  Input:   default_permission(1=deny, 2=read only, 3=read/write)
#           smb_admin(administrator account of samba)
#           deny_user(array of deny user)
#           deny_group(array of deny group)
#           ro_user(array of read only user)
#           ro_group(array of read only group)
#           rw_user(array of read/write user)
#           rw_group(array of read/write group)
#  Output:  Hash of samba permission strings
#  Example: get_smb_perm_string(3, "administrator", \@deny_user, \@deny_group, \@ro_user, \@ro_group, \@rw_user, \@rw_group);
###########################################################
sub get_smb_perm_string {
	my ($default_perm,$smb_admin,$smb_users,$deny_user_ref,$deny_group_ref,$ro_user_ref,$ro_group_ref,$rw_user_ref,$rw_group_ref,$unset_aduser)=@_;
	my @deny_user  = @$deny_user_ref;
	my @deny_group = @$deny_group_ref;
	my @ro_user    = @$ro_user_ref;
	my @ro_group   = @$ro_group_ref;
	my @rw_user    = @$rw_user_ref;
	my @rw_group   = @$rw_group_ref;

	my @unset_user = @$unset_aduser;
	
	my %smb_perm_string = ();
		
	my $writeable = "no";
	my $invalid_user = "";
	my $valid_user = "$smb_admin";  # by default
	my $read_list = "";
	my $write_list = "$smb_admin";  # by default
	# deny access
	if ($default_perm == 1) {
		$writeable = "yes";
		# set deny group(do not setting)
		# set deny user
		for $data (@deny_group) {
			if ($invalid_user ne "") {
				$invalid_user .= ",";
			}
			$invalid_user .= "@\"$data\"";
		}
		for $data (@deny_user){
            if ($invalid_user ne "") {
	                $invalid_user .= ",";
 	        }
           $invalid_user .= "\"$data\"";
		}
		for $data (@unset_user) {
			if ($invalid_user ne "") {
				$invalid_user .= ",";
			}
			$invalid_user .= "\"$data\"";
		}

		#set read only group
		for $data (@ro_group) {
			if ($read_list ne "") {
				$read_list .= ",";
			}
			$valid_user .= ",@\"$data\"";
			$read_list .= "@\"$data\"";
		}
		#set read only user
		for $data (@ro_user) {
			if ($read_list ne "") {
				$read_list .= ",";
			}
			$valid_user .= ",\"$data\"";
			$read_list .= "\"$data\"";
		}
		#set read/write group
		for $data (@rw_group) {
			$valid_user .= ",@\"$data\"";
			$write_list .= ",@\"$data\"";
		}
		#set read/write user
		for $data (@rw_user) {
			$valid_user .= ",\"$data\"";
			$write_list .= ",\"$data\"";
		}
	}
	# read only
	elsif ($default_perm == 2) {
		$writeable = "yes";
		$valid_user .= ",$smb_users";
		# set deny group
		for $data (@deny_group) {
			if ($invalid_user ne "") {
				$invalid_user .= ",";
			}
			$invalid_user .= "@\"$data\"";
		}
		# set deny user
		for $data (@deny_user) {
			if ($invalid_user ne "") {
				$invalid_user .= ",";
			}
			$invalid_user .= "\"$data\"";
		}
		#set read only group(do not setting)
		for $data (@ro_group){
			if ($read_list ne "") {
				$read_list .= ",";
			}
			$read_list .= "@\"$data\"";
		}
		#set read only user
		for $data (@ro_user) {
			if ($read_list ne "") {
				$read_list .= ",";
			}
			$read_list .= "\"$data\"";
		}
		for $data (@unset_user) {
			if ($read_list ne "") {
				$read_list .= ",";
			}
			$read_list .= "\"$data\"";
		}

		#set read/write group
		for $data (@rw_group) {
			$write_list .= ",@\"$data\"";
		}
		#set read/write user
		for $data (@rw_user) {
			$write_list .= ",\"$data\"";
		}
	}
	# read/write
	elsif ($default_perm == 3) {
		$writeable = "yes";
		$valid_user .= ",$smb_users";
		# set deny group
		for $data (@deny_group) {
			if ($invalid_user ne "") {
				$invalid_user .= ",";
			}
			$invalid_user .= "@\"$data\"";
		}
		# set deny user
		for $data (@deny_user) {
			if ($invalid_user ne "") {
				$invalid_user .= ",";
			}
			$invalid_user .= "\"$data\"";
		}
		#set read only group
		for $data (@ro_group) {
			if ($read_list ne "") {
				$read_list .= ",";
			}
			$read_list .= "@\"$data\"";
		}
		#set read only user
		for $data (@ro_user) {
			if ($read_list ne "") {
				$read_list .= ",";
			}
			$read_list .= "\"$data\"";
		}
		#set read/write group(do not setting)
		for $data (@rw_group){
				$write_list .= ",@\"$data\"";
		}
		#set read/write user
		for $data (@rw_user) {
			$write_list .= ",\"$data\"";
		}
		for $data (@unset_user) {
			$write_list .= ",\"$data\"";
		}

	}
	
	#print "writeable = $writeable\n";
	#print "invalid users = $invalid_user\n";
	#print "valid users = $valid_user\n";
	#print "read list = $read_list\n";
	#print "write list = $write_list\n";
	
	$smb_perm_string{"writeable"} = "$writeable";
	$smb_perm_string{"invalid_user"} = "$invalid_user";
	$smb_perm_string{"valid_user"} = "$valid_user";
	$smb_perm_string{"read_list"} = "$read_list";
	$smb_perm_string{"write_list"} = "$write_list";
	
	return %smb_perm_string;
}

return 1;
