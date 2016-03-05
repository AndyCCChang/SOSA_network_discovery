###################################################################
#  (C) Copyright Promise Technology Inc., 2013 All Rights Reserved
#  Name: lib/acc_parse_lib.pl
#  Author: Minging.Tsai.
#  Date: 2013/7/24.
#  Parameter: None
#  OutputKey: None
#  ReturnCode: None
#  Description: Common functions for other perls.
###################################################################

require "/nasapp/perl/lib/cmd_path.pl";
require "/nasapp/perl/lib/conf_path.pl";

########################################################################
#	input:	[none]
#	output:	[0: OK, 2=No available uid, 3=Invalid uid exists]
########################################################################

sub parse_domainconf {
	#my $HELIOS_LDAP_CONF = "/islavista/config/sw/ldap_mac.conf";
	my @domainconf;#return value
	$domainconf[0] = 0;
	my $HELIOS_LDAP_CONF = "/etc/ldap.conf";
	my $HELIOS_AUTH_CONF = "/islavista/config/sw/auth.conf";
	
	if(! -e $HELIOS_LDAP_CONF) {#/etc/ldap.conf doesn't exist => no doamin join
		print "$HELIOS_LDAP_CONF doesn't exist.";
		return @domainconf;
	}
	
	my $host_ip = "";
	my $base_dc = "";
	my $bind_dn = "";
	my $bind_pw = "";
	my $netbios = "";

	open(my $CONF_IN, $HELIOS_LDAP_CONF);
	while(<$CONF_IN>) {
		
		if(/^host\s+(\d+\.\d+\.\d+\.\d+)/) {
			print $_;
			$host_ip = $1;
			#print "host_ip = $host_ip\n";
		} elsif(/^base\s*(.+)/) {
			print $_;
			$base_dc = $1;	
			$base_dc =~ s/\s+//g;
			#print "base_dc = $base_dc\n";

		} elsif(/^bindpw\s+(\S+)/) {
			print $_;
			$bind_pw = $1;
			#print "bind_pw = $bind_pw\n";
		} elsif(/^binddn\s+(.+)/) {
			print $_;
			$bind_dn = $1;
			$bind_dn =~ s/\s+//g;
			#print "bind_dn = $bind_dn\n";
			
		}		
	}
	close($CONF_IN);	
	
	my $domain = "";
    open(my $CONF_IN, $HELIOS_AUTH_CONF);
    while(<$CONF_IN>) {
		if(/Samba_NetBios_Name=(\S+)/) {
			$netbios = $1;
		} elsif(/ServerType=(\S+)/) {
			$domain = $1;
		}
	}
	close($CONF_IN);	
	print "Distinguish domain type by bind_dn\n";
	#Distinguish domain type by bind_dn
	if($domain eq "ad") {
		$domain = 1;#AD domain
		print "AD domain\n";
		#AD domain has different parameter type when join.
		my @adconf = parse_adsconf($host_ip, $base_dc, $bind_dn, $bind_pw);#To get kdc
		$domainconf[0] = 1;#1:AD 2:LDAP PDC 3:OD
		$domainconf[1] = $host_ip;#host_ip
		$domainconf[2] = $adconf[0];#base_dc
		$domainconf[3] = $adconf[1];#kdc
		$domainconf[4] = $adconf[2];#admin_user
		$domainconf[5] = $bind_pw;#bind_pw
			
	}  elsif($domain eq "ol") {
		print "LDAP PDC domain\n";
		$domain = 2;#LDAP
		$domainconf[0] = 2;#1:AD 2:LDAP 3:OD
		$domainconf[1] = $host_ip;
		$domainconf[2] = "none";
		$domainconf[3] = $base_dc;
		$domainconf[4] = $bind_dn;
		$domainconf[5] = $bind_pw;		
		$domainconf[6] = $netbios;		
	} elsif($domain eq "od") {
		print "ODS domain\n";
		$domain = 3;#ODS domain
		$domainconf[0] = 3;#1:AD 2:LDAP 3:OD
		$domainconf[1] = $host_ip;
		$domainconf[2] = "none";
		$domainconf[3] = $base_dc;
		$domainconf[4] = $bind_dn;
		$domainconf[5] = $bind_pw;		
	}
	return @domainconf;

}
########################################################################
#   Minging.Tsai. 2013/7/25
#   For parse_domainconf to re-format parameter of AD domain.
#	input:	[none]
#	output:	[0: OK, 2=No available uid, 3=Invalid uid exists]
########################################################################
sub parse_adsconf{
	print "In parse_adsconf!!\n";
	my($host_ip, $base_dc, $bind_dn, $bind_pw) = @_;	
	
	my @adsconf = {};
	#ldapsearch -h 192.168.207.55 -p 389 -x -D "MINGING\administrator" -w "Promise111" -b "dc=minging,dc=com,dc=tw" | grep "OU=Domain Controllers"
	
	
	#Get kdc
	$base_dc =~ s/dc=/DC=/g; #dc=minging,dc=com,dc=tw to DC=minging,DC=com,DC=tw
	my $cmd = "ldapsearch -h $host_ip -p 389 -x -b \"$base_dc\" -D \"$bind_dn\" -w $bind_pw | grep \"OU=Domain Controllers,\s*$base_dc\" |";
	#my $cmd = "$LDAPSEARCH_CMD -h $host_ip -p 389 -x -b $base_dc -D $bind_dn -w $bind_pw | grep \"OU=Domain Controllers\" |";
	print "cmd = $cmd\n";		
	my $kdc = "";
	open(my $LDAP_IN, $cmd);
	while(<$LDAP_IN>) {
		print $_;
		#dn: CN=MINGING2003,OU=Domain Controllers,DC=minging,DC=com,DC=tw
		if(/^dn\:\s+CN=(\S+),OU=Domain Controllers,$base_dc/) {
			$kdc = $1;
			last;
		}
	}
	close($LDAP_IN);
	
	#Get domain name
	#DC=minging,DC=com,DC=tw to minging.com.tw
	#$base_dc =~ s/,DC=/\./g;
	#$base_dc =~ s/DC=//g;
	
	#Get NetBios and admin user
	my $netbios = "";
	my $admin_user = "";
	if($bind_dn =~ /(\S+)\\(\S+)/) {#MINGING\administrator get administrator
		$netbios = $1;
		$admin_user	= $2;
	}
	#"minging.com.tw" "minging2003" "administrator" "Promise111" "minging"
	$adsconf[0] = $base_dc;#Not use now
	$adsconf[1] = $kdc;
	$adsconf[2] = $admin_user;
	$adsconf[3] = $bind_pw;#Not use now
	$adsconf[4] = $netbios;#Not use now	
	
	return @adsconf;
}
return 1;  # this is required.
