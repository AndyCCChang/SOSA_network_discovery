#!/usr/bin/perl
#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: pro_ftp_lib.pl
#  Author: Paul Chang
#  Date: 2012/12/13
#  Description:
#    Functions to modify ftp config file.
#########################################################################

require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/pro_lib.pl";

#########################################################
#  Set ftp settings.
#  Input:   port                       connection port(number)
#           passiveport_start          start of passive connection port(number)
#           passiveport_end            end of passive connection port(number)
#           remote_charset             character set type(UTF-8, SJIS, GB18030, BIG5, or UHC)
#           protocol_type              protocol type(0=standard ftp, 1=explicit, 2=implicit, 3=sftp)
#           timeout                    connetion time out(number)
#           download_rate_protocol     download rate of all user(number, 0=no limit)
#           download_rate_anonymous    download rate of anonymous user(number, 0=no limit)
#           upload_rate_protocol       upload rate of all user(number, 0=no limit)
#           upload_rate_anonymous      upload rate of anonymous user(number, 0=no limit)
#           max_client_protocol        max connection of normal user(number)
#           max_client_anonymous       max connection of anonymous user(number)
#           anonymous_enabled          anoaymous user enabled(1=enabled, 0=disabled)
#  Output:  0=OK
#  Example: setftpconfig(21, 1024, 65535, "UTF-8", 0, 30, 0, 0, 0, 0, 255, 255, 0);
#########################################################
sub setftpconfig {
	my $port = $_[0];
	my $passiveport_start = $_[1];
	my $passiveport_end = $_[2];
	my $protocol_type = $_[3];
	my $timeout = $_[4];
	my $download_rate_protocol = $_[5];
	my $download_rate_anonymous = $_[6];
	my $upload_rate_protocol = $_[7];
	my $upload_rate_anonymous = $_[8];
	my $max_client_protocol = $_[9];
	my $max_client_anonymous = $_[10];
	#my $anonymous_enabled = $_[11];
	
	chomp($port);
	chomp($passiveport_start);
	chomp($passiveport_end);
	chomp($protocol_type);
	chomp($timeout);
	chomp($download_rate_protocol);
	chomp($download_rate_anonymous);
	chomp($upload_rate_protocol);
	chomp($upload_rate_anonymous);
	chomp($max_client_protocol);
	chomp($max_client_anonymous);
#	chomp($anonymous_enabled);
	
	# use to determin protocol setting or anonymous user setting 
	my $c_flag = 0; 
	my $p_flag = 0; 
	my $a_flag = 0;
	my $m_flag = 0;
	my $d_flag = 0;
	my $u_flag = 0;
	my $t_flag = 0;
    my $s_flag = 0;
	
	# TODO check if port is valid
#	$ftptmp = gen_random_filename("$FTP_CONF");
	$origin_ftp = "/etc/proftpd.src";
	$ftptmp = "/nasdata/config/etc/proftpd.setting";
#	print "$ftptmp\n";
#	system("$CP_CMD -f $FTP_CONF $origin_ftp");
	open(my $OUT, ">$ftptmp");
	open(my $IN, "<$origin_ftp");
	while (<$IN>) {
		if (/^Port\s+/) {
			if ( $a_flag == 0 ) {
				print $OUT "Port\t\t\t\t$port\n";
			}
			$a_flag = 1;
		}
		elsif (/PassivePorts/) {
			if ($passiveport_start ne "" && $passiveport_end ne "") {
				print $OUT "PassivePorts\t\t\t$passiveport_start\t$passiveport_end\n";
			}	    
			$p_flag = 1;
		}
		elsif (/TimeoutIdle/) {
			print $OUT "TimeoutIdle\t\t\t$timeout\n";
		}
		elsif (/MaxClients/) {
			#if ($m_flag == 0) {
				print "MaxClients\t\t\t$max_client_protocol\n";
			#	$m_flag = 1;
			#}
			#elsif ($m_flag == 1) {
			#	print $OUT "\tMaxClients\t\t\t$max_client_anonymous\n";
			#}
			print $OUT "MaxClients\t\t\t$max_client_protocol\n";
		}
		elsif (/TransferRate RETR/) {
			#if ($d_flag == 0) {
			#	print $OUT "TransferRate RETR\t\t\t$download_rate_protocol\n";
			#	$d_flag = 1;
			#}
			#elsif ($d_flag == 1) {
			#	print $OUT "\tTransferRate RETR\t\t\t$download_rate_anonymous\n";
			#}
			print $OUT "TransferRate RETR\t\t\t$download_rate_protocol\n";
		}
		elsif (/TransferRate STOR/) {
			#if ($u_flag == 0) {
			#	print $OUT "TransferRate STOR\t\t\t$upload_rate_protocol\n";
			#	$u_flag = 1;
			#}
			#elsif ($u_flag == 1) {
			#	print $OUT "\tTransferRate STOR\t\t\t$upload_rate_anonymous\n";
			#}
			print $OUT "TransferRate STOR\t\t\t$upload_rate_protocol\n";
		}
		elsif (/DefaultRoot/) {
			if ($p_flag == 0) {
				if ($passiveport_start ne "" && $passiveport_end ne "") {
					print $OUT "PassivePorts\t\t\t$passiveport_start\t$passiveport_end\n";
				}
			}
			print $OUT "$_";
		}
		elsif (/^\s*#\<\s*IfModule\s+mod_tls.c\s*\>/) {
			$t_flag = 1;
		}
		elsif ($t_flag == 1 && /^s*#\<\/IfModule\>/) {
			$t_flag = 0;
		}
		elsif (/^\s*\<\s*IfModule\s+mod_sftp.c\s*\>/) {
			$s_flag = 1;
		}
		elsif ($s_flag == 1 && /^s*\<\/IfModule\>/) {
			$s_flag = 0;
		}
		elsif (/# TLS/) {
			print $OUT "$_";
			if ($protocol_type == 1) {     # SSL(explicit)
				print $OUT "<IfModule mod_tls.c>\n";
				print $OUT "\tTLSEngine on\n";
				print $OUT "\tTLSOptions NoCertRequest NoSessionReuseRequired\n";
				print $OUT "\tTLSLog /dev/null\n";
				print $OUT "\tTLSProtocol TLSv1\n";
				print $OUT "\tTLSProtocol SSLv23\n";
				print $OUT "\tTLSRequired on\n";
   				print $OUT "\tTLSRSACertificateFile /etc/proftpd/ssl/ftp.cert.pem\n";
				print $OUT "\tTLSRSACertificateKeyFile   /etc/proftpd/ssl/ftp.key.pem\n";
				print $OUT "\tTLSCACertificateFile /etc/proftpd/ssl/ftp.cert.pem\n";
				print $OUT "\tTLSVerifyClient off\n";
				print $OUT "</IfModule>\n";
			}
			elsif ($protocol_type == 2) {  # SSL(implicit)
				print $OUT "<IfModule mod_tls.c>\n";
				print $OUT "\tTLSEngine on\n";
				print $OUT "\tTLSOptions NoCertRequest NoSessionReuseRequired UseImplicitSSL\n";
				print $OUT "\tPort 990\n";
				print $OUT "\tTLSLog /dev/null\n";
				print $OUT "\tTLSProtocol TLSv1\n";
				print $OUT "\tTLSProtocol SSLv23\n";
				print $OUT "\tTLSRequired on\n";
   				print $OUT "\tTLSRSACertificateFile /etc/proftpd/ssl/ftp.cert.pem\n";
				print $OUT "\tTLSRSACertificateKeyFile   /etc/proftpd/ssl/ftp.key.pem\n";
				print $OUT "\tTLSCACertificateFile /etc/proftpd/ssl/ftp.cert.pem\n";
				print $OUT "\tTLSVerifyClient off\n";
				print $OUT "</IfModule>\n";
			}
			elsif ($protocol_type == 3) {  # sftp
				print $OUT "<IfModule mod_sftp.c>\n";
				print $OUT "\tSFTPEngine on\n";
				print $OUT "\tSFTPLog /var/log/proftpd.log\n";
				print $OUT "\tSFTPHostKey /etc/ssh/ssh_host_rsa_key\n";
				print $OUT "\tSFTPHostKey /etc/ssh/ssh_host_dsa_key\n";
				print $OUT "\tSFTPAuthorizedUserKeys file:~/.sftp/authorized_keys\n";
				print $OUT "\tSFTPCompression delayed\n";
				print $OUT "\tMaxLoginAttempts 10\n";
				print $OUT "</IfModule>\n";
			}
		}	
		elsif ($t_flag == 0 && $s_flag == 0) {
			print $OUT "$_";
		}
	}
	
	close($IN);
	close($OUT);
#	system("cat $ftptmp");
#	copy_file_to_realpath($ftptmp, $FTP_CONF);
#	unlink($origin_ftp);
#	unlink($ftptmp);

	#if ($anonymous_enabled == 1) {
	#	system("$RM_CMD -rf $FTP_ANONYMOUS");
	#}
	#else {
	#	open (my $OUT, ">$FTP_ANONYMOUS");
	#	printf $OUT "ftp";
	#	close($OUT);
	#}

	#mark_reload_protocol("FTP");
	return 0;
}

#########################################################
#  Get ftp settings
#  Input:   -
#  Output:  a hash contains information with keys
#           {port, passiveport_start, passiveport_end, remote_charset, protocol_type, download_rate_protocol, download_rate_anonymous
#            upload_rate_protocol, upload_rate_anonymous, max_client_protocol, max_client_anonymous, anonymous_enabled}
#  Example: getftpconfig();
#########################################################
sub getftpconfig {
	# use to determin protocol setting or anonymous user setting
	my $m_flag = 0;
	my $d_flag = 0;
	my $u_flag = 0;
	my $t_flag = 0;
	my %result=();
	
	# initialize result
	$result{"port"} = 21;
	$result{"passiveport_start"} = 1024;
	$result{"passiveport_end"}   = 65535;
	$result{"protocol_type"} = 0;
	$result{"timeout"} = 0;
	$result{"download_rate_protocol"} = 0;
	$result{"download_rate_anonymous"} = 0;
	$result{"upload_rate_protocol"} = 0;
	$result{"upload_rate_anonymous"} = 0;
	$result{"max_client_protocol"} = 256;
	$result{"max_client_anonymous"} = 256;

	$origin_ftp = "/nasdata/config/etc/proftpd.setting";
	#my $origin_ftp = gen_random_filename("$FTP_CONF");
#	system("$CP_CMD -f $FTP_CONF $origin_ftp");
	open (my $IN, "<$origin_ftp");
	while (<$IN>) {
		if (/^Port\s+(\S+)/) {
			$result{"port"} = $1;
		}
		elsif (/PassivePorts\s+(\S+)\s+(\S+)/) {
			$result{"passiveport_start"} = $1;
			$result{"passiveport_end"}   = $2;
		}
		elsif ( /TLSOptions NoCertRequest NoSessionReuseRequired$/ ) {
			$result{"protocol_type"} = 1;
		}
		elsif ( /TLSOptions NoCertRequest NoSessionReuseRequired UseImplicitSSL$/ ) {
			$result{"protocol_type"} = 2;
		}
		elsif ( /SFTPEngine on/ ) {
			$result{"protocol_type"} = 3;
		}
		elsif (/TransferRate RETR\s+(\S+)/) {
			#if ($d_flag == 0) {
			#	$result{"download_rate_protocol"} = $1;
			#	$d_flag = 1;
			#}
			#elsif ($d_flag == 1) {
			#	$result{"download_rate_anonymous"} = $1;
			#}
			$result{"download_rate_protocol"} = $1;
			$result{"download_rate_anonymous"} = $1;
		}
		elsif (/TransferRate STOR\s+(\S+)/) {
			#if ($u_flag == 0) {
			#	$result{"upload_rate_protocol"} = $1;
			#	$u_flag = 1;
			#}
			#elsif ($u_flag == 1) {
			#	$result{"upload_rate_anonymous"} = $1;
			#}
			$result{"upload_rate_protocol"} = $1;
			$result{"upload_rate_anonymous"} = $1;
		}
		elsif (/TimeoutIdle\s+(\S+)/) {
			$result{"timeout"} = $1;
		}
		elsif (/MaxClients\s+(\S+)/) {
			#if ($m_flag == 0) {
			#	$result{"max_client_protocol"} = $1;
			#	$m_flag = 1;
			#}
			#elsif ($m_flag == 1) {
			#	$result{"max_client_anonymous"} = $1;
			#}
			$result{"max_client_protocol"} = $1;
			$result{"max_client_anonymous"} = $1;
		}
	}
	close($IN);
#	unlink($origin_ftp);
	
	#if ( -f "$FTP_ANONYMOUS" ) {
	#	open (my $IN, "<$FTP_ANONYMOUS");
	#	while (<$IN>) {
	#		if (/ftp/) {
	#			$result{"anonymous_enabled"} = 0;
	#		}
	#	}
	#}
	#close($IN);
#	$result{"anonymous_enabled"} = 0;
	
	return %result;
}

###########################################################
#  Get ftp permission string
#  Input:   default_permission(1=deny, 2=read only, 3=read/write)
#           deny_user(array of deny user)
#           deny_group(array of deny group)
#           ro_user(array of read only user)
#           ro_group(array of read only group)
#           rw_user(array of read/write user)
#           rw_group(array of read/write group)
#  Output:  Hash of ftp permission strings
#  Example: get_ftp_perm_string(3, \@deny_user, \@deny_group, \@ro_user, \@ro_group, \@rw_user, \@rw_group);
###########################################################
sub get_ftp_perm_string {
	my ($default_perm,$ftp_admin,$ftp_users,$deny_user_ref,$deny_group_ref,$ro_user_ref,$ro_group_ref,$rw_user_ref,$rw_group_ref,$unset_aduser)=@_;
	my @deny_user  = @$deny_user_ref;
	my @deny_group = @$deny_group_ref;
	my @ro_user    = @$ro_user_ref;
	my @ro_group   = @$ro_group_ref;
	my @rw_user    = @$rw_user_ref;
	my @rw_group   = @$rw_group_ref;
	my @unset_user = @$unset_aduser;
	
	my %ftp_perm_string = ();
	my $rwallowuser = "$ftp_admin";
	my $rwallowgroup = "";
	my $rwdenyuser = "";
	my $rwdenygroup = "";
	my $roallowuser = "$ftp_admin";
	my $roallowgroup = "";
	my $rodenyuser = "";
	my $rodenygroup = "";


	for $data (@unset_user){
		$data =~ s/\\/\\\\/g;
		$data =~ s/ /\\ /g;
        $rwdenyuser .= " \"$data\"";
        $rodenyuser .= " \"$data\"";
	}	
	# set deny group
	for $data (@deny_group) {
		$data =~ s/\\/\\\\/g;
		$data =~ s/ /\\ /g;
			$rwdenygroup .= " \"$data\"";
			$rodenygroup .= " \"$data\"";
	}
	# set deny user
	for $data (@deny_user) {
		$data =~ s/\\/\\\\/g;
		$data =~ s/ /\\ /g;
		$rwdenyuser .= " \"$data\"";
		$rodenyuser .= " \"$data\"";
	}
	#set read only group
	for $data (@ro_group) {
		$data =~ s/\\/\\\\/g;
		$data =~ s/ /\\ /g;
		$roallowgroup .= " \"$data\"";
	}
	#set read only user
	for $data (@ro_user) {
		$data =~ s/\\/\\\\/g;
		$data =~ s/ /\\ /g;
#		$rwdenyuser .= " \"$data\"";
		$roallowuser .= " \"$data\"";
	}
	#set read/write group
	for $data (@rw_group) {
		$data =~ s/\\/\\\\/g;
		$data =~ s/ /\\ /g;
#		if ($default_perm == 1) {
			$rwallowgroup .= " \"$data\"";
			$roallowgroup .= " \"$data\"";
#		}
#		elsif ($default_perm == 2) {
#			$rwallowgroup .= " \"$data\"";
#		}
#		elsif ($default_perm == 3) {
#		}
	}
	#set read/write user
	for $data (@rw_user) {
		$data =~ s/\\/\\\\/g;
		$data =~ s/ /\\ /g;
		$rwallowuser .= " \"$data\"";
		$roallowuser .= " \"$data\"";
	}
	
	#print "rwallowuser = $rwallowuser\n";
	#print "rwallowgroup = $rwallowgroup\n";
	#print "rwdenyuser = $rwdenyuser\n";
	#print "rwdenygroup = $rwdenygroup\n";
	#print "roallowuser = $roallowuser\n";
	#print "roallowgroup = $roallowgroup\n";
	#print "rodenyuser = $rodenyuser\n";
	#print "rodenygroup = $rodenygroup\n";
	
	$ftp_perm_string{"rwallowuser"} = "$rwallowuser";
	$ftp_perm_string{"rwallowgroup"} = "$rwallowgroup";
	$ftp_perm_string{"rwdenyuser"} = "$rwdenyuser";
	$ftp_perm_string{"rwdenygroup"} = "$rwdenygroup";
	$ftp_perm_string{"roallowuser"} = "$roallowuser";
	$ftp_perm_string{"roallowgroup"} = "$roallowgroup";
	$ftp_perm_string{"rodenyuser"} = "$rodenyuser";
	$ftp_perm_string{"rodenygroup"} = "$rodenygroup";
	
	return %ftp_perm_string;
}


return 1;
