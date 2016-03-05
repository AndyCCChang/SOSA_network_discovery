#!/usr/bin/perl
require "/nasapp/perl/lib/common.pl";


sub getlvsip{
	my ($lvsip)=@_;
	my @ripary=();
        open(IN,"/islavista/config/NAS_APP/" . $lvsip . "/rip.conf");
        while(<IN>){
                  print "$_";
                  if(/(.+)/){
	               push @ripary,$1;
	          }
	}
	close(IN);
	return @ripary;                                                                                                        
}


sub sendlvscmd{
	my (@parameter)=@_;
	my $lvsip = $parameter[0];
	my $nasip="";
	my @ripary=();
	my @data=();
	my $result="";
	@ripary = getlvsip($lvsip);
	foreach $nasip(@ripary){
	   	 print "nasip=$nasip\n";
		 $parameter[0] = $nasip;
		 $result = sendcmd(@parameter);
		 push @data,{ "lvsip" =>$lvsip ,"ip" => $nasip , "Json" => $result};;
	}
	return @data;
}
sub sendcmd{
    my (@parameter)=@_;
	my $argcnt = @parameter;
	my $ip = $parameter[0];
	my $command =  $parameter[1];
	my $Json = "{\"params\":[";
	my $i=0;
	my $result ="";
	my $authresult = "";
	for($i=2;$i<$argcnt;$i++){
		if($i > 2){
			$Json = $Json . ",";
		}
		$Json = $Json . "\"$parameter[$i]\"";
	}
	$Json = $Json . "]";
	$Json = $Json . ",\"method\":\"$command\"}";
	my $r = &get_random(12);
	my $tmp_file = "/tmp/" . $ip . "_" . $r;
	
	$command = "/usr/bin/wget --tries=1 --timeout=30 https://" . $ip . "/DataProvider.php --post-data 'parameter=" . $Json ."' --no-check-certificate -O $tmp_file 1>/dev/null 2>/dev/null";
	print "$command\n";
	system($command);
	open(IN,"$tmp_file");
	$result = <IN>;
	close(IN);
	$result =~ s/[\x0A\x0D]//g;
	system("rm $tmp_file");
	return $result;
}


sub getHeliosIP{
	my $Heliosip = "";
	open(IN,"/nasdata/config/etc/join_info.conf");
	while(<IN>){
		if(/HELIOS_JOIN=(\S+)/){
			$Heliosip = $1;
		}	
	}
	close(IN);
	return $Heliosip;
}

sub sendtoHelios{
    my (@parameter)=@_;
	print "@parameter\n";
	my $Heliosip = "";
	open(IN,"/nasdata/config/etc/join_info.conf");
	while(<IN>){
		if(/HELIOS_JOIN=(\S+)/){
			$Heliosip = $1;
		}	
	}
	close(IN);
	print "$Heliosip\n";
	if($Heliosip eq "" || $Heliosip eq "none"){
			return -1; 
	}
	
	my $command =  $parameter[0];
	my $argcnt = @parameter;
	my $Json = "{\"params\":[";
	my $i=0;
	my $result ="";
	my $authresult = "";
	for($i=1;$i<$argcnt;$i++){
		if($i > 1){
			$Json = $Json . ",";
		}
		$Json = $Json . "\"$parameter[$i]\"";
	}
	$Json = $Json . "]";
	$Json = $Json . ",\"method\":\"$command\"}";
	my $r = &get_random(12);
    my $tmp_file = "/tmp/" . $r;
	$command = "/usr/bin/wget --tries=1 --timeout=30 --connect-timeout=5 https://" . $Heliosip . "/nas_gateway/DataProvider.php --post-data 'parameter=" . $Json ."' --no-check-certificate -O $tmp_file 1>/dev/null 2>/dev/null";
	print "$command\n";
	system($command);
	open(IN,"$tmp_file");
	$result = <IN>;
	close(IN);
	$result =~ s/[\x0A\x0D]//g;
	system("rm $tmp_file");
	print "result = [$result]\n";
	return $result;
}

sub sendtoGW{
    my (@parameter)=@_;
	print "@parameter\n";
	
	my $argcnt = @parameter;
	my $ip = $parameter[0];
	my $command =  $parameter[1];
	my $Json = "{\"params\":[";
	my $i=0;
	my $result ="";
	my $authresult = "";
	for($i=2;$i<$argcnt;$i++){
		if($i > 2){
			$Json = $Json . ",";
		}
		$Json = $Json . "\"$parameter[$i]\"";
	}
	$Json = $Json . "]";
	$Json = $Json . ",\"method\":\"$command\"}";
	my $r = &get_random(12);
    my $tmp_file = "/tmp/" . $r;
	$command = "/usr/bin/wget --tries=1 https://" . $ip . "/DataProvider.php --post-data 'parameter=" . $Json ."' --no-check-certificate -O $tmp_file 1>/dev/null 2>/dev/null";
	system($command);
	open(IN,"$tmp_file");
	$result = <IN>;
	close(IN);
	$result =~ s/[\x0A\x0D]//g;
	system("rm $tmp_file");
	print "result = [$result]\n";
	return $result;
}

sub sendtoGWshort{
    my (@parameter)=@_;
	#print "@parameter\n";
	
	my $argcnt = @parameter;
	my $ip = $parameter[0];
	my $command =  $parameter[1];
	my $Json = "{\"params\":[";
	my $i=0;
	my $result ="";
	my $authresult = "";
	for($i=2;$i<$argcnt;$i++){
		if($i > 2){
			$Json = $Json . ",";
		}
		$Json = $Json . "\"$parameter[$i]\"";
	}
	$Json = $Json . "]";
	$Json = $Json . ",\"method\":\"$command\"}";
	my $r = &get_random(12);
    my $tmp_file = "/tmp/" . $r;
	$command = "/usr/bin/wget --tries=1 --timeout=6 https://" . $ip . "/DataProvider.php --post-data 'parameter=" . $Json ."' --no-check-certificate -O $tmp_file 1>/dev/null 2>/dev/null";
	system($command);
	open(IN,"$tmp_file");
	$result = <IN>;
	close(IN);
	$result =~ s/[\x0A\x0D]//g;
	system("rm $tmp_file");
	#print "result = [$result]\n";
	return $result;
}

sub exportlvsfs
{
	 my($lvsip,$exportfs)=@_;
	 @ripary = getlvsip($lvsip);
	 foreach $NASip(@ripary){	 
		 system("/nasapp/perl/util/Helios_set_acc_perm.pl add $exportfs $NASip");	
	}
}

sub unexportlvsfs
{
	 my($lvsip,$exportfs)=@_;
	 @ripary = getlvsip($lvsip);
	 foreach $NASip(@ripary){
		system("/nasapp/perl/util/Helios_set_acc_perm.pl del $exportfs $NASip");	 
	 }
}

sub UnMountfromHelios
{
	my ($lvsip,$HeliosMountPoint) = @_;	
	my $exportfs="";
	if($HeliosMountPoint =~/\/\S+\/(\S+)/){
               $exportfs = $1;
        }
	@result = sendlvscmd($lvsip,"nas_umountfromhelios","/$exportfs");
		
	if($exportfs ne ""){
		unexportlvsfs($lvsip,$exportfs);	
	}
	return @result;	
}

sub MounttoHelios
{
	my ($lvsip,$Heliosip,$HeliosMountPoint,$NASMountPoint) = @_;
	my $exportfs="";
	my @command = {};
	my @ripary = {};
	my @data = ();
	my $result=();	
	my @para=();
	my $option;
	if($HeliosMountPoint =~/\/\S+\/(\S+)/){
		$exportfs = $1;
	}

	if($exportfs ne ""){
#		system("/nasapp/perl/util/Helios_set_acc_perm.pl add $exportfs $NASip");
		exportlvsfs($lvsip,$exportfs);
	}
	@para = GetDefaultServiceParameter();
	
	foreach my $parameter(@para){
		if($parameter->{'PROTO'} eq "BWFS"){
			$option = $parameter->{'OPTION'};			
		}
	}
	print "option = $option\n";
	@result = sendlvscmd($lvsip,"nas_mountohelios",$Heliosip,$HeliosMountPoint,$NASMountPoint,$option);
	return @result;
}

sub GetDefaultServiceParameter
{
	my @data = ();
	my $SCONF;
	my  $service;
	open($SCONF,"/islavista/config/NAS_APP/ServiceConf.conf");
	while(<$SCONF>){
        	if(/\[(\S+)\]/){
                       print "$1\n";
	               $service = $1;
                }elsif(/OPTION=(\d+)/){
                       push @data, {"PROTO" =>$service , "OPTION" =>$1}
                }
        }
        close($SCONF);
        return @data;                                                                

}
sub SetDefaultServiceParameter
{
	my (@para)=@_;
	my $SCONF;
	my $parameter;
	open ($SCONF,">/tmp/serviceconf");
	foreach $parameter(@para){
		print $SCONF "[" .$parameter->{'PROTO'} . "]\n";
		print $SCONF "OPTION=" . $parameter->{'OPTION'} . "\n";
	}
	close($SCONF);
	system("cp /tmp/serviceconf /islavista/config/NAS_APP/ServiceConf.conf");	
}
return 1;  # this is required.
