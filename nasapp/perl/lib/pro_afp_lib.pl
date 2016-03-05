#!/usr/bin/perl
#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: pro_afp_lib.pl
#  Author: Paul Chang
#  Date: 2012/12/13
#  Description:
#    Functions to modify afp config file.
#########################################################################

require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/pro_lib.pl";

#########################################################
#  Set afp settings(welcome message)
#  Input:   welcome_message
#  Output:  -
#  Example: setftpconfig("welcome");
#########################################################
sub setafpconfig {
	my ($loginmsg) = @_;

	my $afptmp = gen_random_filename("$AFP_MSG_CONF");
	open(my $OUT, ">$afptmp");
	if ($loginmsg ne "") {
		print $OUT "-uamlist uams_dhx2.so,uams_clrtxt.so,uams_dhx.so -nosavepassword -tcp -loginmesg \"" . $loginmsg ."\" \\\n";
		print $OUT "-setuplog \"default LOG_INFO /var/log/netatalk.log\" \\\n";
		print $OUT "-setuplog \"UAMS LOG_ERROR /var/log/afpd-uam.log\"\n";
	}
	else {
		print $OUT "-uamlist uams_dhx2.so,uams_clrtxt.so,uams_dhx.so -nosavepassword -tcp \\\n";
		print $OUT "-setuplog \"default LOG_INFO /var/log/netatalk.log\" \\\n";
		print $OUT "-setuplog \"UAMS LOG_ERROR /var/log/afpd-uam.log\"\n";
	}
	close($OUT);
	
	copy_file_to_realpath($afptmp, $AFP_MSG_CONF);
	unlink($afptmp);
	mark_reload_protocol("AFP");
	return 0;
}

#########################################################
#  Get afp settings(welcome message)
#  Input:   -
#  Output:  welcome_message
#  Example: getftpconfig();
#########################################################
sub getafpconfig {
	my $loginmsg = "";
	
	open(my $IN, "<$AFP_MSG_CONF");
	while(<$IN>) {
		if (/-loginmesg\s+\"([\S\s]*\S+)\"/) {
			$loginmsg = $1;
		}
	}
	close($IN);
	
	return $loginmsg;
}

###########################################################
#  Get afp permission string
#  Input:   default_permission(1=deny, 2=read only, 3=read/write)
#           deny_user(array of deny user)
#           deny_group(array of deny group)
#           ro_user(array of read only user)
#           ro_group(array of read only group)
#           rw_user(array of read/write user)
#           rw_group(array of read/write group)
#  Output:  Hash of afp permission strings
#  Example: get_afp_perm_string(3, \@deny_user, \@deny_group, \@ro_user, \@ro_group, \@rw_user, \@rw_group);
###########################################################
sub get_afp_perm_string {
	my ($default_perm,$afp_admin,$afp_users,$deny_user_ref,$deny_group_ref,$ro_user_ref,$ro_group_ref,$rw_user_ref,$rw_group_ref)=@_;
	my @deny_user  = @$deny_user_ref;
	my @deny_group = @$deny_group_ref;
	my @ro_user    = @$ro_user_ref;
	my @ro_group   = @$ro_group_ref;
	my @rw_user    = @$rw_user_ref;
	my @rw_group   = @$rw_group_ref;
	
	my %afp_perm_string = ();
	
	my $allow = "$afp_admin";  # by default
	my $deny = "";
	my $rolist = "";
	
	# deny access
	if ($default_perm == 1) {
		# set deny group(do not setting)
		# set deny user
		for $data (@deny_user) {
			if ($deny ne "") {
				$deny .= ",";
			}
			$deny .= "\"$data\"";
		}
		# set read only group
		for $data (@ro_group) {
			if ($rolist ne "") {
				$rolist .= ",";
			}
			$allow .= ",@\"$data\"";
			$rolist .= "@\"$data\"";
		}
		# set read only user
		for $data (@ro_user) {
			if ($rolist ne "") {
				$rolist .= ",";
			}
			$allow .= ",\"$data\"";
			$rolist .= "\"$data\"";
		}
		# set read/write group
		for $data (@rw_group) {
			$allow .= ",@\"$data\"";
		}
		# set read/write user
		for $data (@rw_user) {
			$allow .= ",\"$data\"";
		}	
	}
	# read only
	elsif ($default_perm == 2) {
		$allow .= ",$afp_users";
		$rolist .= "$afp_users";
		
		# set deny group
		for $data (@deny_group) {
			if ($deny ne "") {
				$deny .= ",";
			}
			$deny .= "@\"$data\"";
		}
		
		# set deny user
		for $data (@deny_user) {
			if ($deny ne "") {
				$deny .= ",";
			}
			$deny .= "\"$data\"";
		}
		# set read only group(do not setting)
		# set read only user(do not setting)
		# set read/write group(do not setting)
		# set read/write user(do not setting)
	}
	# read/write
	elsif ($default_perm == 3) {
		$allow .= ",$afp_users";

		# set deny group
		for $data (@deny_group) {
			if ($deny ne "") {
				$deny .= ",";
			}
			$deny .= "@\"$data\"";
		}
		
		# set deny user
		for $data (@deny_user) {
			if ($deny ne "") {
				$deny .= ",";
			}
			$deny .= "\"$data\"";
		}
		#set read only group
		for $data (@ro_group) {
			if ($rolist ne "") {
				$rolist .= ",";
			}
			$rolist .= "@\"$data\"";
		}
		#set read only user
		for $data (@ro_user) {
			if ($rolist ne "") {
				$rolist .= ",";
			}
			$rolist .= "\"$data\"";
		}
		#set read/write group(do not setting)
		#set read/write user(do not setting)
	}
	
	#print "allow = $allow\n";
	#print "deny = $deny\n";
	#print "rolist = $rolist\n";
	
	$afp_perm_string{"allow"} = "$allow";
	$afp_perm_string{"deny"} = "$deny";
	$afp_perm_string{"rolist"} = "$rolist";
	
	return %afp_perm_string;
}

return 1;