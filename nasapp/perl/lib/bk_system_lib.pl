#!/usr/bin/perl
#########################################################################################################
#   (C) Copyright Promise Technology Inc., 2012 All Rights Reserved                                     #
#  Name: bk_system_lib.pl                                                                               #
#  Author: Kinix                                                                                        #
#  Date: 2013/03/13                                                                                     #
#  Description: This perl is some sub routines for system about backup tasks.                           #
#               ResetBackupTaskToDefault    <- ReloadBackup                                             #
#               ReloadBackup                <- ReloadBackupServer, ReloadBackupTask                     #
#               ReloadBackupServer                                                                      #
#               ReloadBackupTask            <- ClearTaskSchedules                                       #
#               ClearTaskSchedules                                                                      #
#               ExportBackup                                                                            #
#               ImportBackup                <- ReloadBackup                                             #
#               ShareDiskRenameForBackup                                                                #
#########################################################################################################
require "/nasapp/perl/lib/common.pl";        #gen_random_filename
require "/nasapp/perl/lib/cmd_path.pl";      #$RM_CMD, $CP_CMD, $MV_CMD, $MKDIR_CMD, $REALPATH_CMD, $GETHISCTLRINFO_CMD
require "/nasapp/perl/lib/conf_path.pl";     #$NASDATA_SRC_CONFIG_PATH, $RSYNCD_CONF, $DATA_PATH, $CONF_CRONTAB
require "/nasapp/perl/lib/bk_def.pl";
require "/nasapp/perl/lib/bk_server_lib.pl"; #RefineRsyncdConfFile, RestartSSHDaemon, RestartRsyncDaemon, RsyncServerRenameShareDisk
require "/nasapp/perl/lib/bk_ssh_lib.pl";    #SyncNasData
require "/nasapp/perl/lib/bk_task_lib.pl";   #SetTaskSchedule, BackupTaskRenameShareDisk

######################################################
# ResetBackupTaskToDefault                           #
#   Remove all back tasks in this node and the other #
######################################################
sub ResetBackupTaskToDefault
{
	system("$RM_CMD -rf $SSHRSYNC_PREFIX");
	system("$RM_CMD -rf $BK_TASK_PREFIX/*");
	system("$CP_CMD -af \"$NASDATA_SRC_CONFIG_PATH$RSYNCD_CONF\"* \"$DATA_PATH/etc\"");
	system("$CP_CMD -af \"$NASDATA_SRC_CONFIG_PATH$SSHD_CONF\" \"$DATA_PATH/etc\"");
	SyncNasData();
	ReloadBackup();
}


##########################################################
# ReloadBackup                                           #
#   Reload backup server and all backup task settings    #
##########################################################
sub ReloadBackup
{
	### Reload backup server ###
	ReloadBackupServer();
	### Reload backup tasks ###
	ReloadBackupTask();
}


############################################
# ReloadBackupServer                       #
#   Check configure file and reload server #
############################################
sub ReloadBackupServer
{
	RestartSSHDaemon();
	RefineRsyncdConfFile();
	RestartRsyncDaemon();
}


#######################################
# ReloadBackupTask                    #
#   Reload backup tasks into schedule #
#######################################
sub ReloadBackupTask
{
	ClearTaskSchedules();

	### Backup mode ###
	my $DIR, $dirName = "";
	opendir($DIR, $BK_BACKUP_PREFIX);
	while($dirName = readdir($DIR)) {
		if($dirName eq "." || $dirName eq "..") {
			next;
		}
		SetTaskSchedule("update", $BK_MODE_BACKUP, $dirName);
	}
	closedir($DIR);

	### Replication mode ###
	opendir($DIR, $BK_REPLICATION_PREFIX);
	while($dirName = readdir($DIR)) {
		if($dirName eq "." || $dirName eq "..") {
			next;
		}
		SetTaskSchedule("update", $BK_MODE_REPLICATION, $dirName);
	}
	closedir($DIR);
}


##########################################
# ClearTaskSchedules                     #
#   Clear all task schedules from contab #
##########################################
sub ClearTaskSchedules
{
	my $inCrontab = gen_random_filename();
	my $outCrontab = gen_random_filename();
	system("$CP_CMD -af \"$CONF_CRONTAB\" \"$inCrontab\"");
	open(my $OUT, "> $outCrontab");
	open(my $IN, "< $inCrontab");
	while(<$IN>) {
		if(/$PL_BKRSYNCTASK/) {
			next;
		}
		else {
			print $OUT "$_";
		}
	}
	close($OUT);
	close($IN);
	unlink($inCrontab);
	system("$MV_CMD -f \"$outCrontab\" \"$CONF_CRONTAB\"");
}


########################################################
# ExportBackup                                         #
#   Export all backup tasks settings                   #
#   Input:                                             #
#           $_[0]: The folder path that will export to #
#   Return:                                            #
#           0:Success                                  #
#           1:Fail                                     #
########################################################
sub ExportBackup
{
	my $dirPath = shift;
	return 1 if(!-d $dirPath);

	### Export backup server ###
	system("$MKDIR_CMD -p \"$dirPath/etc\"");
	system("$CP_CMD -af \"$DATA_PATH$RSYNCD_CONF\"* \"$dirPath/etc\"");

	### Export backup tasks ###
	my $realpath_conf = `$REALPATH_CMD $BK_TASK_PREFIX 2>/dev/null`;
	chomp($realpath_conf);
	system("$CP_CMD -af \"$realpath_conf\" \"$dirPath/etc\"");
	return 0;
}


##########################################################
# ImportBackup                                           #
#   Import all backup tasks settings                     #
#   Input:                                               #
#           $_[0]: The folder path that will import from #
#   Return:                                              #
#           0:Success                                    #
#           1:Fail                                       #
##########################################################
sub ImportBackup
{
	my $dirPath = shift;
	return 1 if(!-d $dirPath);

	### Import backup server ###
	my $role = `$GETHISCTLRINFO_CMD -m`; chomp($role);
	system("$CP_CMD -af \"$dirPath/$RSYNCD_CONF\"* \"$DATA_PATH/etc/\"") if(-f "$dirPath/$RSYNCD_CONF$role");
	### Import backup tasks ###
	if(-d "$dirPath/$BK_TASK_PREFIX") {
		system("$RM_CMD -rf $BK_TASK_PREFIX/*");
		system("$CP_CMD -af \"$dirPath/$BK_TASK_PREFIX/\"* \"$BK_TASK_PREFIX/\" 2>/dev/null");
	}
	### Sync nasdata ###
	SyncNasData();
	### Reload backup ###
	ReloadBackup();
	return 0;
}


########################################
# ShareDiskRenameForBackup             #
#   Rename Share Disk for backup part  #
#   Input:                             #
#           $_[0]: Old Share Disk name #
#           $_[1]: New Share Disk name #
#   Return:                            #
#           0:Success, 1:Fail          #
########################################
sub ShareDiskRenameForBackup
{
	my $oldName = shift;
	my $newName = shift;

	return 1 if($oldName eq "" || $newName eq "");

	#Backup server part
	RsyncServerRenameShareDisk($oldName, $newName);

	#Backup tasks part
	BackupTaskRenameShareDisk($oldName, $newName);

	return 0;
}


