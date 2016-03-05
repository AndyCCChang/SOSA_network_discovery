#!/usr/bin/perl
#########################################################################################################
#   (C) Copyright Promise Technology Inc., 2012 All Rights Reserved                                     #
#  Name: bk_def.pl                                                                                      #
#  Author: Kinix                                                                                        #
#  Date: 2012/10/22                                                                                     #
#  Description: This perl is for definition of backup.                                                  #
#########################################################################################################

#perl
$PL_BKSERVER              = "/nasapp/perl/bk_server.pl";
$PL_BKBROWSEUTIL          = "/nasapp/perl/util/bk_browse_util.pl";
$PL_BKRSYNCRECOVERY       = "/nasapp/perl/util/bk_rsyncrecovery.pl";
$PL_BKRSYNCRECOVERYTRYSWB = "/nasapp/perl/util/bk_rsyncrecoverytryswb.pl";
$PL_BKRSYNCRESTORE        = "/nasapp/perl/util/bk_rsyncrestore.pl";
$PL_BKRSYNCTASK           = "/nasapp/perl/util/bk_rsynctask.pl";
$PL_BKSYSTEMUTIL          = "/nasapp/perl/util/bk_system_util.pl";
$PL_PRONFSEXPORTS         = "/nasapp/perl/util/pro_nfsexports.pl";
$PL_SYSCONFIGBK           = "/nasapp/perl/util/sys_configbk.pl";

#backdoor daemon
$BDSHD_PORT = "234";
$BDRYC_PORT = "235";
$BDRYC_CMD = "/nasapp/bin/bdryc";
$BDRYC_CNF = "/nasapp/bin/bdryc.conf";

#backup cpu core define
$CPU_CORE_BACKUP_SERVER = "2";
$CPU_CORE_RSYNC_CLIENT  = "3";

#Share Disk
$SNAPSHOT_PREFIX   = "/SN";
$SSHRSYNC_PREFIX   = "/SSHRSYNC";

#revoery
$RECOVERY_PREFIX  = "/FC";
$RECOVERY_SWB_MAX = 24;		# recovery switch back counter limit

#backup task
$BK_TASK_MAX           = 32;
$BK_TASK_PREFIX        = "/etc/bkTasks";
$BK_TASK_CONFFILE      = "setting.conf";
$BK_TASK_PIDFILE       = "running.pid";
$BK_TASK_PROGRESSFILE  = "progress.info";
$BK_TASK_RESULT        = "result.out";
$BK_TASK_SOURCELIST    = "source.list";
$BK_MODE_BACKUP        = "Backup";
$BK_MODE_CLONE         = "Clone";
$BK_MODE_REPLICATION   = "Replication";
$BK_BACKUP_PREFIX      = "$BK_TASK_PREFIX/$BK_MODE_BACKUP";
$BK_CLONE_PREFIX       = "$BK_TASK_PREFIX/$BK_MODE_CLONE";
$BK_REPLICATION_PREFIX = "$BK_TASK_PREFIX/$BK_MODE_REPLICATION";

#backup task policy
$BK_POLICY_MIRROR = "0";
$BK_POLICY_COPY   = "1";
$BK_POLICY_SNAP   = "2";

#rsync server
$BK_SSHD_PORT      = "872";
$BK_RSYNCD_PORT    = "873";
$BK_SERVER_COMMENT = "Share Disk for rsync backup";

#rsync connection timeout
$BK_RSYNC_CONTIMEOUT = 3;


return 1;
