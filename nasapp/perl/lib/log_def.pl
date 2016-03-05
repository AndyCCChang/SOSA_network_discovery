#!/usr/bin/perl
#########################################################################################################
#   (C) Copyright Promise Technology Inc., 2012 All Rights Reserved                                     #
#  Name: log_def.pl                                                                                     #
#  Author: Kinix                                                                                        #
#  Date: 2013/03/15                                                                                     #
#  Description: Log number definition.                                                                  #
#########################################################################################################

#log level
$LOG_ERROR       = "1";
$LOG_WARNING     = "2";
$LOG_INFORMATION = "3";

#log code of functionality
#File System
$LOG_FS_VOLUME    = "01";
$LOG_FS_SHAREDISK = "02";
$LOG_FS_QUOTA     = "03";
$LOG_FS_PROTOCOL  = "04";

#Backup
$LOG_BK_SERVER      = "11";
$LOG_BK_REPLICATION = "12";
$LOG_BK_RECOVERY    = "13";
$LOG_BK_FILEBACKUP  = "14";
$LOG_BK_SNAPSHOT    = "15";
$LOG_BK_CLONE       = "16";

#Account
$LOG_ACC_NASUSER       = "21";
$LOG_ACC_NASGROUP      = "22";
$LOG_ACC_DOMAIN        = "23";
$LOG_ACC_PERMISSION    = "24";
$LOG_ACC_IMPORTNASUSER = "25";

#Misc
$LOG_MISC_BACKUPRESTORE = "31";
$LOG_MISC_RESESETTINGS  = "32";
$LOG_MISC_NASEVENT      = "33";

$NET_EVENT				= "34";
$RAID_EVENT             = "35";
$LOG_NAS_MOUNT			= "36";
$LOG_HELIOS				= "37";
$LOG_NAS_CONFIG			= "38";
$LOG_NAS_FW				= "39";
return 1;
