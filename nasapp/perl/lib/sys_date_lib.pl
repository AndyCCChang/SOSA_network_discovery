#!/usr/bin/perl
#########################################################################
#    (C) Copyright Promise Technology Inc., 2013 All Rights Reserved
#  Name: lib/sys_date_lib.pl
#  Author: Minging.Tsai
#  Date: 2013/9/26
#  Parameter: -
#  OutputKey: -
#  ReturnCode: -
#  Description:
#    Set NAS gateway to sync time with Helios.
#########################################################################
#Minging.Tsai. 2013/10/3.  Change date sync procedure to cluster level.
#Minging.Tsai. 2013/10/4.  Add naslog.
#Minging.Tsai. 2013/10/18. Add for NAS gateway use.

sub get_date
{
	my @date = ();
	my @month_ary = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	
	open(my $DATE_IN, "/bin/date -u |");
	while(<$DATE_IN>) {
		#   Tue   Sep     10     07  :  14  :  44    UTC   2013
		if(/\S+\s+(\S+)\s+(\d+)\s+(\d+)\:(\d+)\:(\d+)\s+\S+\s+(\d+)/) {
            $month_str = $1;
            $day = $2;
            $hour = $3;
            $minute = $4;
            $second = $5;
            $year = $6;
			last;
		}
	}
	close($DATE_IN);
	$month = 0;
	#Convert month_string to month (number).
	for(my $i = 0; $i < 12; $i++) {
		if($month_ary[$i] eq $month_str) {
			$month = $i + 1;
			last;
		}
	}
	$timezone = get_tz();
	
	push @date, { "month_str" => "$month_str", "month" => "$month","day" => "$day", "year" => "$year", "hour" => "$hour", "minute" => "$minute", "second" => "$second", "timezone" => "$timezone"};
	return @date;
}

sub get_tz
{
	my $tz_string = "";
	open($TZ_IN, "/etc/sysconfig/clock");
	while(<$TZ_IN>) {
		if(/# ZONE_INDEX="(\S+)"/) {
			$tz_string = $1;
			last;
		}
	}
	close($TZ_IN);
	return $tz_string;
}
return 1;

