#!/usr/bin/perl
#########################################################################################################
#   (C) Copyright Promise Technology Inc., 2012 All Rights Reserved                                     #
#  Name: fs_crypt_lib.pl                                                                                #
#  Author: Kinix                                                                                        #
#  Date: 2013/01/04                                                                                     #
#  Description: This perl is for some sub routines for disk encryption.                                 #
#               LuksOpen      <- AnalyzeDevice, ReadKF                                                  #
#               LuksClose     <- AnalyzeDevice, KillKF                                                  #
#               LuksFormat    <- AnalyzeDevice, KeepKF                                                  #
#               LuksChangeKey <- KillKF, KeepKF                                                         #
#               LuksSaveKey   <- KillKF, KeepKF                                                         #
#               LuksStatus    <- ReadKF                                                                 #
#########################################################################################################
require "/nasapp/perl/lib/common.pl";      #gen_random_filename
require "/nasapp/perl/lib/cmd_path.pl";    #$CRYPTSETUP_CMD, $LVDISPLAY_CMD, $BASE64_CMD, $RM_CMD
require "/nasapp/perl/lib/conf_path.pl";   #$CRYPTKEY_PATH
require "/nasapp/perl/lib/bk_ssh_lib.pl";  #SyncFileToRemote

#########################################
# Open Linux Unified Key Setup(Luks)    #
#   Input:                              #
#           $_[0]: device path          #
#           $_[1]: password             #
#           $_[2]: snapshot device path #
#           $_[3]: specified name       #
#   Return:                             #
#           0 for success               #
#           1 for fail case             #
#           2 for wrong argument(s)     #
#           3 for password incorrect    #
#           4 for device is in use      #
#########################################
sub LuksOpen
{
	my $device = shift;
	my $passwd = shift;
	my $snapDevice = shift;
	my $encryptDevice = shift;
	my $result = 0;

	$passwd = ReadKF($device) if($passwd eq "");
	if($passwd eq "") {
		return 2;
	}
	$encryptDevice = AnalyzeDevice($device) if($encryptDevice eq "");
	if($encryptDevice eq "") {
		return 2;
	}

	$device = $snapDevice if($snapDevice ne "");
	my $inputFile = gen_random_filename();
	my $errorFile = gen_random_filename();
	system("echo $passwd >$inputFile 2>/dev/null");
	system("$CRYPTSETUP_CMD luksOpen $device $encryptDevice <$inputFile >/dev/null 2>$errorFile");
	unlink("$inputFile");
	open(my $IN, "<$errorFile");
	while(<$IN>) {
		if(/No key available with this passphrase./) {
			print $_;
			$result = 3;
		}
		elsif(/Device $encryptDevice already exists./) {
			print $_;
			$result = 1;
		}
		elsif(/Cannot use device $device which is in use \(already mapped or mounted\)./) {
			print $_;
			$result = 4;
		}
	}
	close($IN);
	unlink("$errorFile");
	return $result;
}


#################################################
# Close Linux Unified Key Setup(Luks)           #
#   Input:                                      #
#           $_[0]: device path                  #
#           $_[1]: specified name               #
#           $_[2]: remove KF or not (default 1) #
#   Return:                                     #
#           0 for success                       #
#           1 for wrong device                  #
#         256 for Device or resource busy       #
#        1024 for Device not found              #
#################################################
sub LuksClose
{
	my $device = shift;
	my $specifiedName = shift;	#for snapshot of encrypted SD
	my $removekey = shift;
	$removekey = 1 if(!defined($removekey));
	my $result = 0;
	my $encryptDevice = $specifiedName if($specifiedName ne "");
	$encryptDevice = AnalyzeDevice($device) if($specifiedName eq "");
	if($encryptDevice eq "") {
		return 1;
	}
	$result = system("$CRYPTSETUP_CMD luksClose /dev/mapper/$encryptDevice >/dev/null");
	KillKF($device) if(0 == $result && $specifiedName eq "" && 1 == $removekey);
	return $result;
}


########################################
# Format Linux Unified Key Setup(Luks) #
#   Input:                             #
#           $_[0]: device path         #
#           $_[1]: password            #
#           $_[2]: keep password flag  #
#   Return:                            #
#           0 for success              #
#           1 for fail case            #
#           2 for wrong argument(s)    #
########################################
sub LuksFormat
{
	my $device = shift;
	my $passwd = shift;
	my $keeppw = shift;
	my $result = 0;

	if($passwd eq "") {
		return 2;
	}
	my $encryptDevice = AnalyzeDevice($device);
	if($encryptDevice eq "") {
		return 2;
	}

	my $IN;
	my $inputFile = gen_random_filename();
	my $errorFile = gen_random_filename();
	system("echo $passwd >$inputFile 2>/dev/null");
	system("$CRYPTSETUP_CMD -v -c aes-cbc-plain luksFormat $device -q <$inputFile >/dev/null 2>$errorFile");
	open($IN, "<$errorFile");
	while(<$IN>) {
		if(/Cannot format device $device which is still in use./) {
			print $_;
			$result = 1;
		}
	}
	close($IN);
	unlink("$errorFile");
	if($result != 0) {
		unlink("$inputFile");
		return $result;
	}
	system("$CRYPTSETUP_CMD luksOpen $device $encryptDevice <$inputFile >/dev/null 2>$errorFile");
	unlink("$inputFile");
	open($IN, "<$errorFile");
	while(<$IN>) {
		if(/Device $encryptDevice already exists./) {
			print $_;
			$result = 1;
		}
	}
	close($IN);
	unlink("$errorFile");

	KeepKF($device, $passwd) if($keeppw == 1);
	return $result;
}


#####################################################
# Password Change for Linux Unified Key Setup(Luks) #
#   Input:                                          #
#           $_[0]: device path                      #
#           $_[1]: old password                     #
#           $_[2]: new password                     #
#           $_[3]: keep password flag               #
#   Return:                                         #
#           0 for success                           #
#           1 for fail case                         #
#           2 for wrong argument(s)                 #
#####################################################
sub LuksChangeKey
{
	my $device = shift;
	my $oldkey = shift;
	my $newkey = shift;
	my $keeppw = shift;
	my $result = 0;

	if($newkey eq "") {
		return 2;
	}

	my $inputFile = gen_random_filename();
	my $errorFile = gen_random_filename();
	system("echo \"$oldkey\n$newkey\n$newkey\" >$inputFile 2>/dev/null");
	system("$CRYPTSETUP_CMD luksAddKey $device <$inputFile >/dev/null 2>$errorFile");
	unlink("$inputFile");
	open(my $IN, "<$errorFile");
	while(<$IN>) {
		if(/No key available with this passphrase./) {
			print $_;
			$result = 1;
		}
		elsif(/Device $device is not a valid LUKS device./) {
			print $_;
			$result = 1;
		}
	}
	close($IN);
	unlink("$errorFile");
	if($result != 0) {
		return $result;
	}

	system("echo \"$newkey\n\" >$inputFile 2>/dev/null");
	system("$CRYPTSETUP_CMD luksKillSlot $device 0 <$inputFile >/dev/null 2>/dev/null");
	system("echo \"$newkey\n$newkey\n$newkey\" >$inputFile 2>/dev/null");
	system("$CRYPTSETUP_CMD luksAddKey $device <$inputFile >/dev/null 2>/dev/null");
	system("echo \"$newkey\n\" >$inputFile 2>/dev/null");
	system("$CRYPTSETUP_CMD luksKillSlot $device 1 <$inputFile >/dev/null 2>/dev/null");
	unlink("$inputFile");
	KillKF($device);
	KeepKF($device, $newkey) if($keeppw == 1);
	return $result;
}


###################################################
# Password save for Linux Unified Key Setup(Luks) #
#   Input:                                        #
#           $_[0]: device path                    #
#           $_[1]: password                       #
#           $_[2]: keep password flag             #
#   Return:                                       #
#           0 for success                         #
#           1 for fail case                       #
#           2 for wrong argument(s)               #
###################################################
sub LuksSaveKey
{
	my $device = shift;
	my $passwd = shift;
	my $keeppw = shift;
	my $result = 0;

	if($passwd eq "") {
		return 2;
	}

	my $inputFile = gen_random_filename();
	my $errorFile = gen_random_filename();
	system("echo \"$passwd\n$passwd\n$passwd\" >$inputFile 2>/dev/null");
	system("$CRYPTSETUP_CMD luksAddKey $device <$inputFile >/dev/null 2>$errorFile");
	unlink("$inputFile");
	open(my $IN, "<$errorFile");
	while(<$IN>) {
		if(/No key available with this passphrase./) {
			print $_;
			$result = 1;
		}
		elsif(/Device $device is not a valid LUKS device./) {
			print $_;
			$result = 1;
		}
	}
	close($IN);
	unlink("$errorFile");
	if($result != 0) {
		return $result;
	}

	system("echo \"$passwd\n\" >$inputFile 2>/dev/null");
	system("$CRYPTSETUP_CMD luksKillSlot $device 1 <$inputFile >/dev/null 2>/dev/null");
	unlink("$inputFile");
	KillKF($device);
	KeepKF($device, $passwd) if($keeppw == 1);
	return $result;
}


####################################################
# Status of Linux Unified Key Setup(Luks)          #
#   Input:                                         #
#           $_[0]: device path                     #
#   Return:                                        #
#           0 for not encrypted                    #
#           1 for encrypted without password saved #
#           2 for encrypted with password saved    #
####################################################
sub LuksStatus
{
	my $device = shift;
	my $result = 0;

	open(my $IN, "$CRYPTSETUP_CMD luksDump $device 2>/dev/null |");
	while(<$IN>){
		if(/LUKS header information for $device/) {
			$result = 1;
		}
	}
	close($IN);
	$result = 2 if(ReadKF($device) ne "" && $result != 0);
	return $result;
}


######################################################
# Analyze device                                     #
#   Input:                                           #
#           $_[0]: device path                       #
#                  Ex:"/dev/mapper/c_vg2013-lv8970"  #
#                     or "/dev/c_vg2013/lv8970"      #
#                     or "/dev/sdc"                  #
#   Return:                                          #
#           The corresponded device name for encrypt #
######################################################
sub AnalyzeDevice
{
	my $device = shift;
	my $encryptDevice = "";
	my $result = 0;

	open(my $IN, "$LVDISPLAY_CMD $device 2>&1 |");
	while(<$IN>){
		if(/One or more specified logical volume\(s\) not found./) {
			print $_;
			$result = 1;
		}
	}
	close($IN);
	if($result != 0) {
		return $encryptDevice;
	}

	if($device =~ /\/dev\/mapper\/(.+)/) {
		$encryptDevice = $1;
	}
	elsif($device =~ /\/dev\/(.+)\/(.*)/) {
		$encryptDevice = $1;
		$encryptDevice = $encryptDevice."-".$2 if($2 ne "");
	}
	elsif($device =~ /\/dev\/(.+)/) {
		$encryptDevice = $1;
	}
	$encryptDevice = $encryptDevice."_crypt" if($encryptDevice ne "");
	return $encryptDevice;
}


################################
# Keep key file                #
#   Input:                     #
#           $_[0]: device path #
#           $_[1]: password    #
#   Return:                    #
#           0 for success      #
#           1 for fail case    #
################################
sub KeepKF
{
	my $device = shift;
	my $passwd = shift;
	my $result = 1;

	if(! -d "$CRYPTKEY_PATH") {
		mkdir("$CRYPTKEY_PATH", 0700);
	}

	my $uuid = GetDeviceUUID($device);
	if($uuid ne "") {
		$result = system("echo \"$passwd\" | $BASE64_CMD > $CRYPTKEY_PATH/$uuid 2>/dev/null");
		SyncFileToRemote("", "$CRYPTKEY_PATH"); #sync file to another node
	}
	return $result;
}


################################
# Read key file                #
#   Input:                     #
#           $_[0]: device path #
#   Return:                    #
#           The key of device  #
################################
sub ReadKF
{
	my $device = shift;
	my $uuid = GetDeviceUUID($device);
	my $passwd = "";
	if(-f "$CRYPTKEY_PATH/$uuid") {
		$passwd = `$BASE64_CMD -d $CRYPTKEY_PATH/$uuid`;
		chomp($passwd);
	}
	return $passwd;
}


################################
# Kill key file                #
#   Input:                     #
#           $_[0]: device path #
################################
sub KillKF
{
	my $device = shift;
	my $uuid = GetDeviceUUID($device);
	unlink("$CRYPTKEY_PATH/$uuid");
	SyncFileToRemote("", "$CRYPTKEY_PATH"); #sync file to another node
}


################################
# Get device UUID              #
#   Input:                     #
#           $_[0]: device path #
#   Return:                    #
#           The UUID of device #
################################
sub GetDeviceUUID
{
	my $device = shift;
	my $uuid = "";

	open(my $IN, "$LVDISPLAY_CMD $device |");
	while(<$IN>){
		if(/LV UUID\s+(.+)/) {
			$uuid = $1;
			last;
		}
	}
	close($IN);
	return $uuid;
}


