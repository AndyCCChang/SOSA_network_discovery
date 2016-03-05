###################################################################
#  (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: lib/acc_lib.pl
#  Author: Olive
#  Date: 2012/11/08
#  Modifier: Minging.Tsai. 2013/7/19. Add Open Directory support.
#  Modifier: Minging.Tsai. 2013/8/5. Add set_ads_domain_ldap
#  Modifier: Minging.Tsai. 2013/8/27. Take off modification of some configure files:
#										nsswitch.conf (not change anymore)
#										ldap.conf     (only change in LDAP PDC)
#										pam_ldap.conf (only change in LDAP PDC)
#										/etc/pam.d/*  (not change anymore)
#										smb.conf      (same as local when it comes to ODS)
#										kdc.conf      (not change anymore)
#										krb5.conf 	  (not change anymore)
#  Parameter: None
#  OutputKey: None
#  ReturnCode: None
#  Description: Common functions for other perls.
###################################################################

require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/conf_path.pl";
require "/nasapp/perl/lib/common.pl";
require "/nasapp/perl/lib/dir_path.pl";
require "/nasapp/perl/lib/log_db_lib.pl";
require "/nasapp/perl/lib/pro_lib.pl";
require "/nasapp/perl/lib/sys_lib.pl";
require "/nasapp/perl/lib/perm_lib.pl";
require "/nasapp/perl/lib/acc_db_lib.pl";
require "/nasapp/perl/lib/pro_smb_lib.pl";

########################################################################
#	input:	[-]
#	output:	[0: OK]
#	Using to create all user (exclude system user) home dir
########################################################################
sub create_user_homedir
{
    my($HOME_PATH) = @_;
    #create administrator home dir
    if( ! -d "$HOME_PATH/administrator" ){
        system("$MKDIR_CMD $HOME_PATH/administrator");
        system("$MKDIR_CMD $HOME_PATH/administrator/homes");
        system("$CHOWN_CMD administrator:administrator $HOME_PATH/administrator");
        system("$CHMOD_CMD 700 $HOME_PATH/administrator");
    }
}
########################################################################
#	input:	[X]
#	output:	[setting]
########################################################################
sub get_domain_setting
{
    my %setting;
    my $dntmp = gen_random_filename($CONF_DOMAIN);
    system("$CP_CMD -f \"$CONF_DOMAIN\" \"$dntmp\"");
    open(my $IN, $dntmp);
    while (<$IN>) {
        if ( /TYPE\s*=\s*(\S+)/ ) {
            $setting{"type"} = $1;
        }
        elsif ( /DOMAIN\s*=\s*(\S+)/ ) {
            $setting{"domain"} = $1;
        } 
        elsif ( /KDC\s*=\s*(\S+)/ ) {
            $setting{"kdc"} = $1;
        } 
        elsif ( /USER\s*=\s*(\S+)/ ) {
            $setting{"user"} = $1;
        }
        elsif ( /PASSWD\s*=\s*(\S+)/ ) {
            $setting{"passwd"} = $1;
        }
        elsif ( /NETBIOS\s*=\s*(\S+)/ ) {
            $setting{"netbios"} = $1;
        }
        elsif ( /LDAP\s+Security\s*=\s*(\S+)/ ) {
            $setting{"ldap_security"} = $1;
        } 
        elsif ( /Base\s+DN\s*=\s*(\S+)/ ) {
            $setting{"base_dn"} = $1;
        } 
        elsif ( /Root\s+DN\s*=\s*(\S+)/ ) {
            $setting{"root_dn"} = $1;
        }
        elsif ( /Server\s+IP\s*=\s*(\S+)/ ) {
            $setting{"server_ip"} = $1;
        }
        elsif ( /SMB\s+SID\s*=\s*(\S+)/ ) {
            $setting{"smb_sid"} = $1;
        }
    }
    close($IN);
    unlink($dntmp);
    return %setting;
}

########################################################################
#	input:	[domaintype]
#	output:	[0: OK, 3: Join fail]
########################################################################
sub set_none_domain{
    my ($option)=@_[0];
    print "Leaving domain type: $option\n";
	if($option ne "none") {#$option is "update"
	    naslog($LOG_ACC_DOMAIN,$LOG_INFORMATION,"08","Leave domain due to smb.conf.src update. Keep the permission.");
	}

    my %setting = get_domain_setting();
    my $orgdomaintype = $setting{"type"};
    my $org_server_ip = $setting{"server_ip"};

	system("ip route del to " . $org_server_ip . "dev bond0");#Take off the route of origin domain server.

    print "orgdomaintype=$orgdomaintype\n";
	print "org_server_ip=$org_server_ip\n";

    if ( $orgdomaintype eq "ads") {
        if(exist_sd_db("homes")){
            my %setting = get_domain_setting();
            my $tmpfile = gen_random_filename("");
            my $find_cmd = "$FIND_CMD $HOME_PATH -maxdepth 1 -type d  -regex '.+\\\\.*' |sed 's/\\\/FS\\\/homes\\\///'";
            #print "$find_cmd\n";
            system("$find_cmd > $tmpfile");

            print "rename folder\n";
            open(my $IN, "<$tmpfile");
            while (<$IN>) {
                #print "$_\n";
                my $name = $_;
                #print "name:$name\n";
                chomp $name;
                $name =~ s/\\/\\\\/g;
                #print "name:$name\n";
                my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
                $year += 1900;  
                $mon += 1;
                my $new_folder = sprintf("%s.%04d%02d%02d%02d%02d%02d", $name, $year, $mon, $mday, $hour, $min, $sec);

                # Rename $user folder
                system("$MV_CMD $HOME_PATH/$name $HOME_PATH/$new_folder");
            }
            close($IN);
            unlink($tmpfile);
            ## Rename $user home folder [End] ##
        }
        $ret=copy_file_to_realpath($SRC_LDAP_NSLCD_CONF,$LDAP_NSLCD_CONF);
		if($ret==1){
			naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"43","Copy internal file fail.");
		}
    }
    elsif( $orgdomaintype eq "ldap") {#Minging.Tsai 2013/8/5
        print "Leaving from LDAP\n";
        $ret=copy_file_to_realpath($SRC_LDAP_NSLCD_CONF,$LDAP_NSLCD_CONF);
        if($ret==1){
            naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"43","Copy internal file fail.");
        }
    }
	elsif($orgdomaintype eq "ods" ) {
		#Minging.Tsai 2013/8/27
        print "Leaving from ODS or native LDAP\n";

		#Minging.Tsai. 2013/8/27. 
		#Restore the default /etc/passwd and erase the local smb user db when leaving ODs.
		system("$CP_CMD $CONF_PASSWD_SRC $CONF_PASSWD");#Restore the passwd
		system("$RM_CMD /var/lib/samba/private/*");
		system("echo \"\" >/nasdata/config/etc/smbpasswd");#Clear the smbpasswd
		system("echo \"\" >/nasdata/config/etc/passwdod");
		system("ln -s /nasdata/config/etc/smbpasswd /var/lib/samba/private/smbpasswd");
        
        $ret=copy_file_to_realpath($SRC_LDAP_NSLCD_CONF,$LDAP_NSLCD_CONF);
        if($ret==1){
            naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"43","Copy internal file fail.");
        }
    }	

	print "Stop the nslcd and restore the nslcd.conf.\n";
	system("$CP_CMD -f $SRC_LDAP_NSLCD_CONF $LDAP_NSLCD_CONF");
	system("/etc/init.d/nslcd stop");

	#Minging.Tsai. 2014/12/5. Reload protocol will handle the smb.conf restore.
#    print "Restore smb.conf\n";
#	system("$CP_CMD -f $SRC_SMB_CONF $SMB_CONF");

	#Restore current smb option setting
#	my %smb_config = getsmbconfig();
#	my $smb_option = $smb_config{"smboption"};
#	my $smb_decs = $smb_config{"description"};
#	setsmbconfig("", 10);#Minging.Tsai.2014/2/19.
#	print "smb_option=$smb_option, smb_decs=$smb_decs\n";
#	setsmbconfig($smb_decs, $smb_option);

    #Minging.Tsai. 2014/12/8. Terminate the gen_domain_usr when leaving domain.
    system("killall acc_util_gen_domain_usr_db.pl");
	system("rm /tmp/acc_util_gen_domain_usr_db.pl_*");
    unlink("/tmp/del_user_db");
    unlink("/tmp/del_group_db");

	if($option eq "none") {#Don't change permision if we just want to update the smb.conf and its source.
	    # generate SQL
	    $sqlfile = gen_random_filename("");
	    open(OUT, ">$sqlfile");
	    print OUT "delete from AD_USER;\n";
	    print OUT "delete from AD_GROUP;\n";
		print OUT "delete from PERMISSION where PERMISSION.source = '3' or PERMISSION.source = '4';\n";#Delete the permission of domain user and group.
		print OUT "delete from PERM_UNSET where PERM_UNSET.source = '3' or PERM_UNSET.source = '4';\n";
		close(OUT);
	    # execute create user DB.
	    $dbres = exec_acc_sqlfile($sqlfile);
	}
	unlink("/nasdata/config/etc/group_filter.conf");
    print "*************Update $CONF_DOMAIN Config************\n";
    my $dstdomain=gen_random_filename("$CONF_DOMAIN");
    open(my $AOUT,">$dstdomain");
    print $AOUT "TYPE=none\n";
    close($AOUT);
    copy_file_to_realpath($dstdomain,$CONF_DOMAIN);
    unlink($dstdomain);

    naslog($LOG_ACC_DOMAIN,$LOG_INFORMATION,"08","Finish leave domain");
    print "*************done************\n";
	unlink("/tmp/domain_stable");#reset the domain stable counter after leave domain.
	unlink("/tmp/domain_status");#reset the domain stable counter after leave domain.

    return 0;
}
########################################################################
#	input:	-
#	output:	[0: OK]
#	Check LDAP domain setting
########################################################################
sub set_ldap_domain
{
	#This is for LDAP PDC only. The native LDAP won't work.
    my ($domaintype, $security_type, $server_ip, $base_dn, $root_dn, $password, $netbios)=@_;
    my $ret=0;

    print "*********************set_ldap_domain*******************************\n";
    print "security_type: $security_type\n";
    print "server_ip: $server_ip\n";
    print "base_dn: $base_dn\n";
    print "root_dn: $root_dn\n";
    print "password: $password\n";
    print "netbios: $netbios\n";

	#Modify nslcd.conf
#Minging.Tsai. 2014/3/28. Prevent setdomain write flash too often.
#my $tmpnslcd=gen_random_filename("$LDAP_NSLCD_CONF");
    my $tmpnslcd = "/tmp/nslcd.conf.joining";
    open(my $TOUT,">$tmpnslcd");
    if(/uri\s+ldap\:\/\/127.0.0.1\//){
        print $TOUT "#uri ldap://127.0.0.1/\n";
    }
    elsif(/base dc=example,dc=com/){
        print $TOUT "#base dc=example,dc=com\n";
    }
    if(($security_type eq "none") || ($security_type eq "tls")){
        print $TOUT "uri     ldap:\/\/$server_ip\n";
    }
    elsif($security_type eq "ssl"){
        print $TOUT "uri     ldaps:\/\/$server_ip\n";
    }
    print $TOUT "base    group  ou=group,$base_dn\n";
    print $TOUT "base    passwd ou=People,$base_dn\n";
    if($security_type eq "none"){
        print $TOUT "ssl    off\n";
        print $TOUT "tls_reqcert     never\n";
    }
	elsif($security_type eq "tls"){
        print $TOUT "ssl    start_tls\n";
        print $TOUT "tls_reqcert     never\n";
    }
	elsif($security_type eq "ssl"){
		print $TOUT "ssl    on\n";
		print $TOUT "tls_reqcert     never\n";
		#print $TOUT "tls_reqcert     allow\n";
	}
    else {
        print $TOUT "$_"; 
    } 
    close($TOUT);
	print "Link /etc/nslcd.conf to $tmpnslcd to try join.\n";
	system("ln -sf $tmpnslcd /etc/nslcd.conf");
	
	#Minging.Tsai. 2014/12/5. No need to modify smb.conf here.

	system("/etc/init.d/nslcd restart");#Minging.Tsai 2013/8/5

	print "Use LDAP search to check the result.\n";
    $tmp =  gen_random_filename("");
    $smb_sid = "";
	my $ldap_cmd = "";
    if($security_type eq "none") {
		$ldap_cmd = "$LDAPSEARCH_CMD -x -w $password -b '$base_dn' -D '$root_dn' -H 'ldap://$server_ip' '(objectClass=organizationalRole)' dn";
	} else {
		$ldap_cmd = "$LDAPSEARCH_CMD -x -w $password -b '$base_dn' -D '$root_dn' -H 'ldaps://$server_ip' '(objectClass=organizationalRole)' dn";
	}
	#Minging.Tsai. 2014/11/14. Just get the admin user info to verify the server connection.
	print "$ldap_cmd\n";
	system("$ldap_cmd 1>/dev/null 2>$tmp");	

    my $okflag = 0;
    open(my $TIN,$tmp);
    while(<$TIN>){
        print "$_";
        if ( /ldap_sasl_bind\(SIMPLE\):\s+Can't\s+contact\s+LDAP\s+server\s+\(-1\)/ ) {
            $okflag = -1;
        } elsif (/ldap_bind:\s+Invalid\s+credentials\s+\(49\)/) {
			$okflag = -2;
		}
    }
    close($TIN);
    unlink($tmp);

#    if($okflag < 0){        
#Minging.Tsai. 2014/11/28.
#Don't roll back the domain setting whatever the join result is.
    if(0){        
        print "contact fail\n";
		system("/etc/init.d/nslcd stop");#Minging.Tsai 2013/8/5
		print "Restore the link of /etc/nslcd.conf.\n";
		system("ln -sf $LDAP_NSLCD_CONF /etc/nslcd.conf");
		unlink("/tmp/nslcd.conf.joining");

        #Samba
        #Restore Samba Config
		#Just resume the link of smb.conf back to /nasdata which should be "none" status.
		print "Restor the link of smb.conf.\n";
		system("ln -sf $SMB_CONF /etc/samba/smb.conf");
		unlink("/tmp/smb.conf.joining");

		#Minging.Tsai. 2013/9/3. Add some error code.
		if($okflag == -1) {
			#Can't contact LDAP server
			return 106;
		}elsif($okflag == -2) {
			#Invalid credentials
			return 107;
		}
    }
    else{
        my $okflag = 0;
#        system("$NET_CMD getlocalsid >$tmp");
#		my $netbios_uc = uc $netbios;
#        open(my $MIN,$tmp);
#        while(<$MIN>){
#            if ( /SID\s+for\s+domain\s+$netbios_uc\s+is:\s+(\S+\-*\d*)/ ) {
#                $smb_sid = $1;
#            }
#        }
#        close($MIN);
#        unlink($tmp);

        #set to /etc/domain
        my $tmpfile=gen_random_filename("$CONF_DOMAIN");

        system("$CP_CMD $CONF_DOMAIN $tmpfile");
        open(my $POUT,">$tmpfile");
        print $POUT "TYPE=ldap\n"; 
        print $POUT "LDAP Security=$security_type\n"; 
        print $POUT "Base DN=$base_dn\n"; 
        print $POUT "Root DN=$root_dn\n"; 
        print $POUT "Server IP=$server_ip\n"; 
        print $POUT "PASSWD=$password\n"; 
        print $POUT "NETBIOS=$netbios\n"; 
#print $POUT "SMB SID=$smb_sid\n"; 
        close($POUT);
        $ret=copy_file_to_realpath($tmpfile,$CONF_DOMAIN);
        if($ret==1){
			naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"46","Copy internal file fail.");
        }
        unlink($tmpfile);

		print "Update the $LDAP_NSLCD_CONF.\n";
		system("mv /tmp/nslcd.conf.joining $LDAP_NSLCD_CONF");
		system("ln -sf $LDAP_NSLCD_CONF /etc/nslcd.conf");

		#Minging.Tsai. 2014/6/26. Make sure the host name is correct.
		my $hostname = `$HOSTNAME_CMD`;
		chomp($hostname);
		$hostname = uc($hostname);
		sethostname($hostname);	
		print "Update hostname to $hostname\n";

    }    
    return 0;
}
########################################################################
#	input:	-
#	output:	[0: OK]
#	Check Ad domain is updating account or not
########################################################################
sub ldap_update_state
{
    my $upstate = 0;
    my $tmp_status =gen_random_filename("$LDAP_UPDATE_STATUS");
    system("$CP_CMD -f $LDAP_UPDATE_STATUS $tmp_status");
    #check counter of gen_listd.pl process
    open(my $IN, $tmp_status);
    while(<$IN>) {
        if (/(\d+)/) {
            $upstate = $1;
            last;
        }
    }
    close($IN);
    unlink($tmp_status);

    return $upstate;
}
########################################################################
#	input:	-
#	output:	[0: OK]
#	Check password is valid or not
########################################################################
sub is_valid_passwd
{
    my $ret = 1;
    my $passwd= @_[0];
    print "is_valid_passwd passwd: $passwd\n";
    my @chars = split(//, $passwd);
    #  !"#$%&'()*+-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ
    #  [\]^_abcdefghijklmnopqrstuvwxyz{|}~
    for(my $i=0; $i<scalar(@chars); $i++) {
        #print "char:$chars[$i]\n";
        $ord = ord($chars[$i]);
        #print "ord:$ord\n";
        if (($ord < 32) || ($ord == 44) || 
            ($ord == 96) || ($ord > 126))
        {
            print "invalid character\n";
            #invalid character
            $ret = 0;
            last;
        }
    }
    #print "ret:$ret\n";
    return $ret;
}
sub set_ods_domain {
    my ($domaintype,$security_type,$server_ip,$base_dn,$root_dn,$password)=@_;
    my $ret=0;

    print "*********************set_ods_domain*******************************\n";
    print "security_type: $security_type\n";
    print "server_ip: $server_ip\n";
    print "base_dn: $base_dn\n";
    print "root_dn: $root_dn\n";
    print "password: $password\n";

	#Modify nslcd.conf
#    my $tmpnslcd=gen_random_filename("$LDAP_NSLCD_CONF");
    my $tmpnslcd = "/tmp/nslcd.conf.joining";#Minging.Tsai. 2014/3/28.
    open(my $TOUT,">$tmpnslcd");
    if(/uri\s+ldap\:\/\/127.0.0.1\//){
        print $TOUT "#uri ldap://127.0.0.1/\n";
    }
    elsif(/base dc=example,dc=com/){
        print $TOUT "#base dc=example,dc=com\n";
    }
    if(($security_type eq "none") || ($security_type eq "tls")){
        print $TOUT "uri     ldap:\/\/$server_ip\n";
    }
    elsif($security_type eq "ssl"){
        print $TOUT "uri     ldaps:\/\/$server_ip\n";
    }
	print $TOUT "base    $base_dn\n";
    if($security_type eq "none"){
        print $TOUT "ssl    off\n";
        print $TOUT "tls_reqcert     never\n";
    }
    elsif($security_type eq "tls"){
        print $TOUT "ssl    start_tls\n";
        print $TOUT "tls_reqcert     never\n";
    }
	elsif($security_type eq "ssl"){
		print $TOUT "ssl    on\n";
		print $TOUT "tls_reqcert     never\n";
		#print $TOUT "tls_reqcert     allow\n";
	}
    else {
        print $TOUT "$_"; 
    } 
    close($TOUT);
	print "Link $tmpnslcd to /etc/nslcd.conf.\n";
	system("ln -sf $tmpnslcd /etc/nslcd.conf");
#    $ret=copy_file_to_realpath($tmpnslcd,$LDAP_NSLCD_CONF);
#    if($ret==1){
#        naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"43","Copy internal file fail.");
#    }
#    unlink($tmpnslcd);    
     
	#Minging.Tsai. 2013/8/27. smb.conf stay unchange as none domain.

	system("/etc/init.d/nslcd restart");	
    system("service smb restart");

    $tmp =  gen_random_filename("");
    $smb_sid = "";
	print "Use ldapsearch to check the result.\n";
	my $ldap_cmd = "";

    if($security_type eq "none"){
		$ldap_cmd = "$LDAPSEARCH_CMD -x -w $password -b '$base_dn' -D '$root_dn' -H 'ldap://$server_ip' '(sn=Administrator)' dn";
	} else {
		$ldap_cmd = "$LDAPSEARCH_CMD -x -w $password -b '$base_dn' -D '$root_dn' -H 'ldaps://$server_ip' '(sn=Administrator)' dn";
	}
	#Minging.Tsai. 2014/11/14. Just get the admin user info to verify the server connection.
	print "$ldap_cmd\n";
	system("$ldap_cmd 1>/dev/null 2>$tmp");
    my $okflag = 0;
    open(my $TIN,$tmp);
    while(<$TIN>){
        print "$_";
        if ( /ldap_sasl_bind\(SIMPLE\):\s+Can't\s+contact\s+LDAP\s+server\s+\(-1\)/ ) {
            $okflag = -1;
        } elsif (/ldap_bind:\s+Invalid\s+credentials\s+\(49\)/) {
		    $okflag = -2;
		}

    }
    close($TIN);
    unlink($tmp);

#    if($okflag < 0){        
    if(0){        
#Minging.Tsai. 2014/11/28.
#Don't roll back the domain setting whatever the join result is.
        print "contact fail\n";
#        naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"47","Contact LDAP [$server_ip] Base DN:[$base_dn] fail.");
		system("/etc/init.d/nslcd stop");
		
		print "Restore the /etc/nslcd.conf to link back to $LDAP_NSLCD_CONF.\n";
		print "ln -sf $LDAP_NSLCD_CONF /etc/nslcd.conf\n";
		system("ln -sf $LDAP_NSLCD_CONF /etc/nslcd.conf");
#        $ret=copy_file_to_realpath($SRC_LDAP_NSLCD_CONF,$LDAP_NSLCD_CONF);
#        if($ret==1){
#            naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"43","Copy internal file fail.");
#        }
        #Minging.Tsai. 2013/9/3. Add some error code.
        if($okflag == -1) {
	        #Can't contact LDAP server
			return 110;
        }elsif($okflag == -2) {
            #Invalid credentials
            return 111;
        }
    }
    else{
		print "contact success\n";
        my $tmpfile=gen_random_filename("$CONF_DOMAIN");

        system("$CP_CMD $CONF_DOMAIN $tmpfile");
        open(my $POUT,">$tmpfile");
        print $POUT "TYPE=ods\n"; 
        print $POUT "LDAP Security=$security_type\n"; 
        print $POUT "Base DN=$base_dn\n"; 
        print $POUT "Root DN=$root_dn\n"; 
        print $POUT "Server IP=$server_ip\n"; 
        print $POUT "PASSWD=$password\n"; 
        #print $POUT "SMB SID=$smb_sid\n"; 
        close($POUT);
        $ret=copy_file_to_realpath($tmpfile,$CONF_DOMAIN);
        if($ret==1){
			naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"46","Copy internal file fail.");
        }
        unlink($tmpfile);

		print "Update the $LDAP_NSLCD_CONF.\n";
		system("mv /tmp/nslcd.conf.joining $LDAP_NSLCD_CONF");
		system("ln -sf $LDAP_NSLCD_CONF /etc/nslcd.conf");

		#Minging.Tsai. 2014/6/26. Make sure the host name is correct.
		my $hostname = `$HOSTNAME_CMD`;
		chomp($hostname);
		$hostname = uc($hostname);
		sethostname($hostname);	
		print "Update hostname to $hostname\n";
    }    
    return 0;
}
########################################################################
#	input:	[domaintype, domain, kdc, username, passwd, permission, netbiosname]
#	output:	[0: OK, 4=Wrong account or password
#              5=Wrong Netbiosname
#              6=System configuration maybe Conflict. Please check current smb.conf]
# Minging.Tsai. 2013/8/5
# Join AD domain by LDAP instead of winbindd
########################################################################
#Minging.Tsai. 2014/3/27. Link /etc/samba/smb.conf to /tmp/smb.conf.joinging when joining
#							write the smb.conf in /nasdata only when the join is OK.
sub set_ads_domain_ldap
{
	my ($domaintype, $server_ip, $base_dn, $kdc, $username, $passwd, $dns)=@_;
    my $homeflag;
    my $admin_user;
    my $tmpret;
    my $retcode=0;
    my $ret=0;
	my $netbiosname = "";
	my $domain = $base_dn;
	
	$domain =~ s/dc=/DC=/g; #dc=minging,dc=com,dc=tw to DC=minging,DC=com,DC=tw
	if($domain =~ /^DC=([^\,]+)\,/) {#Get the first DC as netbiosname
		$netbiosname = $1;
		#change to capital letter
		$netbiosname = "\U$netbiosname";		
	}
	
	#Get domain name
	#DC=minging,DC=com,DC=tw to minging.com.tw
	
	$domain =~ s/,DC=/\./g;
	$domain =~ s/DC=//g;	
	
    print "*********************set_ads_domain*******************************\n";
    print "domaintype: $domaintype\n";
    print "domain: $domain\n";
	print "base_dn: $base_dn\n";
    print "kdc: $kdc\n";
    print "username: $username\n";
    print "passwd: $passwd\n";
    print "netbiosname: $netbiosname\n"; #Minging.Tsai. 2013/8/5

    my %setting = get_domain_setting();
    my $orgdomain = $setting{"type"};
    my $bigdomain = "\U$domain";
    print "bigdomain: $bigdomain\n";
    my $bigkdc = "\U$kdc";
	$bigkdc = $bigkdc.".".$bigdomain if($bigkdc !~ /\d+\.\d+\.\d+\.\d+/);
    print "bigkdc: $bigkdc\n";

    my $hostname = `$HOSTNAME_CMD`;
	chomp($hostname);
	$hostname = uc($hostname);

    #Backup Orignal Config
    print "*********************Do $DOMAIN_CMD stop*******************************\n";
    #system("$DOMAIN_CMD stop");
	system("/etc/init.d/smb stop");
    #SMB
	#print "*********************Backup config*******************************\n";
	#system("$CP_CMD -f $SMB_CONF /tmp/smb.conf.org");
    #DNS
    #system("$CP_CMD -f $CONF_NSSWITCH /tmp/nsswitch.conf.org");
    #AD
    #System
    #system("$CP_CMD -f $CONF_PASSWD /tmp/passwd.org");
	#system("$CP_CMD -f $CONF_HOSTS /tmp/hosts.org");

    #Update /etc/resolv.conf
	#Minging.Tsai. 2013/8/12.
#print "*********************Update /etc/hosts*******************************\n";
	print "nameserver $server_ip\n";
#	my %dnslist = GetResolv();#Keep the origin setting.
	setResolv($dns, 0, 0, 0, 0);#Change DNS1 only.


#Minging.Tsai. 2014/11/28.
#Don't roll back the domain setting whatever the join result is.
    if (1) {#Join OK
        #set to /etc/domain
        my $tmpfile=gen_random_filename("$CONF_DOMAIN");
        print "cp domain\n";
        system("$CP_CMD $CONF_DOMAIN $tmpfile");
        open(my $POUT,">$tmpfile");
        print $POUT "TYPE=ads\n"; 
		print $POUT "Server IP=$server_ip\n";
        print $POUT "DOMAIN=$domain\n"; 
		print $POUT "Base DN=$base_dn\n"; 
        print $POUT "KDC=$kdc\n"; 
        print $POUT "USER=$username\n"; 
        print $POUT "PASSWD=$passwd\n"; 
        print $POUT "NETBIOS=$netbiosname\n";
        close($POUT);
        $ret=copy_file_to_realpath($tmpfile,$CONF_DOMAIN);
        if($ret==1){
            naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"32","Copy internal file:$CONF_DOMAIN.");
        }
        unlink($tmpfile);
		
		#Minging.Tsai. 20113/8/5.
		print "Update nslcd.conf after join OK.\n";
		my $tmpnslcd=gen_random_filename("$LDAP_NSLCD_CONF");
		open(my $TOUT,">$tmpnslcd");
		if(/uri\s+ldap\:\/\/127.0.0.1\//){
			print $TOUT "#uri ldap://127.0.0.1/\n";
		}
		elsif(/base dc=example,dc=com/){
			print $TOUT "#base dc=example,dc=com\n";
		}
		#pass security_type for now
		#Minging.Tsai. 2013/8/5.		
		
		print $TOUT "uri ldap:\/\/$server_ip\n";
		print $TOUT "base $base_dn\n";
		print $TOUT "ssl off\n";
		print $TOUT "tls_reqcert never\n";		
		
		print $TOUT "binddn CN=$username,CN=Users,$base_dn\n";		
		print $TOUT "bindpw $passwd\n";		
		print $TOUT "scope sub\n";		
		print $TOUT "filter passwd (&(objectClass=user)(!(objectClass=computer))(uidNumber=*)(unixHomeDirectory=*))\n";
		print $TOUT "map    passwd homeDirectory    unixHomeDirectory\n";
		print $TOUT "filter shadow (&(objectClass=user)(!(objectClass=computer))(uidNumber=*)(unixHomeDirectory=*))\n";
		print $TOUT "map    shadow shadowLastChange pwdLastSet\n";
		print $TOUT "filter group  (&(objectClass=group)(gidNumber=*))\n";

		close($TOUT);
		$ret=copy_file_to_realpath($tmpnslcd,$LDAP_NSLCD_CONF);
		if($ret==1){
			naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"43","Copy internal file fail.");
		}
		unlink($tmpnslcd);		
		system("chmod 600 /etc/nslcd.conf");
		system("/etc/init.d/nslcd restart");

		#Minging.Tsai. 2013/8/5.
		#Use pam_ldap.so instead of pam_winbind.so now.
		
		#Minging.Tsai. 2013/8/27. We don't change /etc/pam.d/samba anymore.
        
		#Minging.Tsai. 2014/6/26. Make sure the host name is correct.
		sethostname($hostname);
		print "Update hostname to $hostname\n";

        naslog($LOG_ACC_DOMAIN,$LOG_INFORMATION,"11","Join domain success");
        print "\n*********************OK******************************\n";
        return 0;
    }
    else{#Join fail
        print "*********************FAIL******************************\n";
        print "*********************restore configuration******************************\n";
        print "Restore the link of smb.conf to $SMB_CONF.\n";
		system("ln -sf $SMB_CONF /etc/samba/smb.conf");
		unlink("/tmp/smb.conf.joining");
     
        open(my $TMIN, $tmpret);
        $okflag = 0;
        while(<$TMIN>){
            if( /Logon failure/){
                print "Error: Logon failure.\n";
                print "Please check account, password\n";
#naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"12","Join Domain Error:Logon failure, please check account, password.");
                $retcode = 113;
            }
            elsif( /Failed to join domain: failed to find DC for domain/){
                print "Error: Failed to join domain: failed to find DC for domain $netbiosname\n";
                print "Please check Netbiosname\n";
#naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"13","Join Domain Error:failed to find DC for domain [$netbiosname],please check Netbiosname.");
                $retcode = 114;
            }
            elsif(/host is not configured as a member server samba/){
                chomp $_;
#naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"14","Join Domain Error:[$_],please join again.");
                $retcode = 115;
            }
            else{
                chomp $_;
#naslog($LOG_ACC_DOMAIN,$LOG_ERROR,"14","Join Domain Error:[$_],please join again.");
                $retcode = 116;
            }
        }
        close($TMIN);
        unlink($tmpret);
        return $retcode;
    }
}
return 1;  # this is required.
