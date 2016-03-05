#!/usr/bin/perl
#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: pro_webdav_lib.pl
#  Author: Paul Chang
#  Date: 2012/12/13
#  Description:
#    Functions to modify webdav config file.
#########################################################################

require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/pro_lib.pl";

###########################################################
#  Get webdav permission string
#  Input:   default_permission(1=deny, 2=read only, 3=read/write)
#           deny_user(array of deny user)
#           deny_group(array of deny group)
#           ro_user(array of read only user)
#           ro_group(array of read only group)
#           rw_user(array of read/write user)
#           rw_group(array of read/write group)
#  Output:  Hash of webdav permission strings
#  Example: get_webdav_perm_string(3, \@deny_user, \@deny_group, \@ro_user, \@ro_group, \@rw_user, \@rw_group);
###########################################################
sub get_webdav_perm_string {
	my ($default_perm,$webdav_admin,$webdav_users,$deny_user_ref,$deny_group_ref,$ro_user_ref,$ro_group_ref,$rw_user_ref,$rw_group_ref)=@_;
	my @deny_user  = @$deny_user_ref;
	my @deny_group = @$deny_group_ref;
	my @ro_user    = @$ro_user_ref;
	my @ro_group   = @$ro_group_ref;
	my @rw_user    = @$rw_user_ref;
	my @rw_group   = @$rw_group_ref;
	
	my %webdav_perm_string = ();
	my $rouser = "";
	my $rogroup = "";
	my $rwuser = "$webdav_admin";
	my $rwgroup = "";
	
	if ($default_perm == 2) {
		$rogroup .= "$webdav_users";
	}
	elsif ($default_perm == 3) {
		$rwgroup .= "$webdav_users";
	}
	
	for $data (@ro_user) {
		$rouser .= " \"$data\"";
	}
	for $data (@ro_group) {
		$rogroup .= " \"$data\"";
	}
	for $data (@rw_user) {
		$rwuser .= " \"$data\"";
	}
	for $data (@rw_group) {
		$rwgroup .= " \"$data\"";
	}
	
	#print "rouser = $rouser\n";
	#print "rogroup = $rogroup\n";
	#print "rwuser = $rwuser\n";
	#print "rwgroup = $rwgroup\n";
	
	$webdav_perm_string{"rouser"} = "$rouser";
	$webdav_perm_string{"rogroup"} = "$rogroup";
	$webdav_perm_string{"rwuser"} = "$rwuser";
	$webdav_perm_string{"rwgroup"} = "$rwgroup";
	
	return %webdav_perm_string;
}

return 1;