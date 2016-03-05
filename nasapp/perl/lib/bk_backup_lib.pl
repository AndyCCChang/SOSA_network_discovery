#!/usr/bin/perl
#########################################################################################################
#   (C) Copyright Promise Technology Inc., 2012 All Rights Reserved                                     #
#  Name: bk_backup_lib.pl                                                                               #
#  Author: Kinix                                                                                        #
#  Date: 2012/10/22                                                                                     #
#  Description: This perl is some sub routines for backup or it's restore.                              #
#               GenerateSourceListFile  <-  PrintAllSubFolders                                          #
#########################################################################################################
require "/nasapp/perl/lib/bk_def.pl";
require "/nasapp/perl/lib/fs_lib.pl";          #get_share_disk_info
require "/nasapp/perl/lib/bk_task_lib.pl";     #ReadConfigFile, EscapeWildcard

#######################################
# Generate source list file           #
#   Input:                            #
#           $_[0]: backup task name   #
#   Return:                           #
#           0 success                 #
#           1 error                   #
#######################################
sub GenerateSourceListFile
{
	my $taskName = shift;

	my $source = "";
	ReadConfigFile("$BK_BACKUP_PREFIX/$taskName/$BK_TASK_CONFFILE",
		"", "", \$source, "", "", "", "", "", "", "", "");
	if($source eq "") {
		return 1;
	}

	my $match = 0;
	my %hashSD;
	my @shareDiskInfo = get_share_disk_info();
	for(my $i=0; $i<scalar(@shareDiskInfo); $i++) {
		$hashSD{${@shareDiskInfo[$i]}{'sdname'}} = ${@shareDiskInfo[$i]}{'mount_on'};
	}
	open(my $OUT, "> $BK_BACKUP_PREFIX/$taskName/$BK_TASK_SOURCELIST");
	my @shareDisks = split(/\*\*/, $source);
	foreach(@shareDisks) {
		my $diskName = "";
		my $fileList = "";
		my @files = ();
		if($_ =~ /(.+)\:(.*)/) {
			if(0 == $match) {
				$match = 1;
				print $OUT "/**/\n";
			}
			$diskName = "$1";
			$fileList = $2;
			if($fileList ne "") {
				@files = split(/\*/, $fileList);
				foreach(@files) {
					if(-d "$hashSD{$diskName}/$_") {
						print $OUT "/$diskName/".EscapeWildcard($_)."/*\n";
						PrintAllSubFolders($OUT, $hashSD{$diskName}, $diskName, $_);
					}
					else {
						print $OUT "/$diskName/$_\n";
					}
				}
			}
			else {
				print $OUT "/$diskName/*\n";
				PrintAllSubFolders($OUT, $hashSD{$diskName}, $diskName, "");
			}
		}
	}
	close($OUT);
	return 0;
}


#############################################
# Print all sub folders to source file      #
#   Input:                                  #
#           $_[0]: file handler             #
#           $_[1]: Share Disk mount on path #
#           $_[2]: Share Disk name          #
#           $_[3]: folder path              #
#############################################
sub PrintAllSubFolders
{
	my $OUT = shift;
	my $mountOn = shift;
	my $shareDisk = shift;
	my $path = shift;

	if(!-d "$mountOn/$path") {
		return;
	}

	my $DIR;
	opendir($DIR, "$mountOn/$path");
	while($fileName = readdir($DIR)) {
		if($fileName eq "." || $fileName eq "..") {
			next;
		}
		if(-d "$mountOn/$path/$fileName") {
			print $OUT "/$shareDisk/$path/".EscapeWildcard($fileName)."/*\n";
			PrintAllSubFolders($OUT, $mountOn, $shareDisk, "$path/$fileName");
		}
	}
	closedir($DIR);
}

