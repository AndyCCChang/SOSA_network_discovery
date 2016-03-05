#########################################################################
#  (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: lib/cmd_path.pl
#  Author: Fred Shih, Olive Huang, Kylin Shih, Kinix Kao
#  Date: 2012/10/19
#  Parameter: None
#  OutputKey: None
#  ReturnCode: None
#  Description:
#    Command path definition.
#########################################################################

# command @ /bin
*BASE64_CMD   = \"/bin/base64";
*CAT_CMD      = \"/bin/cat";
*CHGRP_CMD    = \"/bin/chgrp";
*CHMOD_CMD    = \"/bin/chmod";
*CHOWN_CMD    = \"/bin/chown";
*CP_CMD       = \"/bin/cp";
*DATE_CMD     = \"/bin/date";
*DD_CMD       = \"/bin/dd";
*DF_CMD       = \"/bin/df";
*ECHO_CMD     = \"/bin/echo";
*GREP_CMD     = \"/bin/grep";
*HOSTNAME_CMD = \"/bin/hostname";
*KILL_CMD     = \"/bin/kill";
*LN_CMD       = \"/bin/ln";
*LS_CMD       = \"/bin/ls";
*MKDIR_CMD    = \"/bin/mkdir";
*MOUNT_CMD    = \"/bin/mount";
*MV_CMD       = \"/bin/mv";
*NETSTAT_CMD  = \"/bin/netstat";
*PS_CMD       = \"/bin/ps ax";
*RM_CMD       = \"/bin/rm";
*RMDIR_CMD    = \"/bin/rmdir";
*SH_CMD       = \"/bin/sh";
*TOUCH_CMD    = \"/bin/touch";
*UNMOUNT_CMD  = \"/bin/umount";
*UNAME_CMD    = \"/bin/uname";
*TAR_CMD      = \"/bin/tar";
*SYNC_CMD     = \"/bin/sync";
*DIFF_CMD	  = \"/bin/diff"; # Henry Wu 2013/07/19
*FIND_CMD     = \"/bin/find"; # Henry Wu 2013/07/19
*ID_CMD       = \"/bin/id"; # Henry Wu 2013/07/19
*KILLALL_CMD  = \"/bin/killall"; # Henry Wu 2013/07/19
*PASSWD_CMD   = \"/bin/passwd"; # Henry Wu 2013/07/19
*REALPATH_CMD = \"/bin/realpath"; # Henry Wu 2013/07/19
#*UNZIP_CMD    = \"/bin/unzip"; # Henry Wu 2013/07/19
*MAIL_CMD     = \"/bin/mail"; # Paul Chang 2013/09/27
*BEEP_CMD     = \"/bin/beep"; # Paul Chang 2013/09/27

# command @ /sbin
*ARPING_CMD		= \"/sbin/arping"; # Henry Wu 2013/07/19
*IFCONFIG_CMD   = \"/sbin/ifconfig";
*HWCLOCK_CMD    = \"/sbin/hwclock";
*MKFS_CMD       = \"/sbin/mkfs.gfs2";
*MKSWAP_CMD     = \"/sbin/mkswap";
*MOUNT_GFS2_CMD = \"/sbin/mount.gfs2";
*FSCK_GFS2_CMD  = \"/sbin/fsck.gfs2";
*MOUNT_GFS2_OPT = \"-o noatime,nodiratime,acl,quota=on";
*GFS2_GROW_CMD	= \"/sbin/gfs2_grow";
*PIDOF_CMD		= \"/sbin/pidof"; # Henry Wu 2013/07/19
*SERVICE_CMD    = \"/sbin/service";
*SWAPOFF_CMD    = \"/sbin/swapoff";
*SWAPON_CMD     = \"/sbin/swapon";
*UDEVADM_CMD    = \"/sbin/udevadm";
*ROUTE_CMD      = \"/sbin/route";
*FUSER_CMD      = \"/sbin/fuser"; # Henry Wu 2013/07/19

# command @ /usr/bin
*CHECK_AUTH_CMD = \"/usr/bin/check_auth";
*CHFN_CMD       = \"/usr/bin/chfn";
*GETENT_CMD     = \"/usr/bin/getent";
*HTPASSWD_CMD   = \"/usr/bin/htpasswd";
*MXARGS_CMD     = \"/usr/bin/mxargs";
*NET_CMD        = \"/usr/bin/net";
*NTPDATE_CMD    = \"/usr/sbin/ntpdate";
*OPENSSL_CMD    = \"/usr/bin/openssl";
*RSYNC_CMD      = \"/usr/bin/rsync";
*SQLITE_CMD     = \"/usr/bin/sqlite3 -cmd \".timeout 3000\"";
*SSH_CMD        = \"/usr/bin/ssh";
*SSHKEYGEN_CMD  = \"/usr/bin/ssh-keygen";
*TASKSET_CMD    = \"/usr/bin/taskset";
*UUIDGEN_CMD    = \"/usr/bin/uuidgen";
*WC_CMD         = \"/bin/wc";
*ZIP_CMD        = \"/usr/bin/zip";
*UNZIP_CMD      = \"/usr/bin/unzip"; # Minging.Tsai. 2013/8/16.
*EEPROMCTL_CMD  = \"/usr/bin/eepromctl";
*IPMITOOL_CMD   = \"/usr/bin/ipmitool";

# command @ /usr/sbin
*CHPASSWD_CMD   = \"/bin/chpasswd"; # Henry Wu 2013/07/19
*CRYPTSETUP_CMD = \"/sbin/cryptsetup"; # Henry Wu 2013/07/19
*EXPORTFS_CMD   = \"/usr/sbin/exportfs";
*GFS2QUOTA_CMD  = \"/usr/sbin/gfs2_quota";
*GFS2TOOL_CMD   = \"/usr/sbin/gfs2_tool";
*GPASSWD_CMD    = \"/usr/sbin/gpasswd";
*GROUPADD_CMD   = \"/usr/sbin/groupadd";
*GROUPDEL_CMD   = \"/usr/sbin/groupdel";
*GROUPS_CMD     = \"/usr/sbin/groups";
*I2ARYTOOL_CMD  = \"/usr/sbin/i2arytool";
*I2ARYTOOL_GET_CMD = \"/usr/sbin/i2arytool_get";
*I2ARYTOOL_SET_CMD = \"/usr/sbin/i2arytool_set";
*LVCHANGE_CMD   = \"/usr/sbin/lvchange";
*LVCREATE_CMD   = \"/usr/sbin/lvcreate";
*LVDISPLAY_CMD  = \"/usr/sbin/lvdisplay";
*LVEXTEND_CMD   = \"/usr/sbin/lvextend";
*LVREMOVE_CMD   = \"/usr/sbin/lvremove";
*LVSCAN_CMD     = \"/usr/sbin/lvscan";
*LVS_CMD        = \"/usr/sbin/lvs";
*NSLCD_CMD      = \"/usr/sbin/nslcd";
*PVCREATE_CMD   = \"/usr/sbin/pvcreate";
*PVREMOVE_CMD   = \"/usr/sbin/pvremove";
*PVSCAN_CMD     = \"/usr/sbin/pvscan";
*PVS_CMD        = \"/usr/sbin/pvs";
*SSHD_CMD       = \"/usr/sbin/sshd";
*USERADD_CMD    = \"/usr/sbin/useradd";
*USERDEL_CMD    = \"/usr/sbin/userdel";
*USERMOD_CMD    = \"/usr/sbin/usermod";
*VGCHANGE_CMD   = \"/usr/sbin/vgchange";
*VGCREATE_CMD   = \"/usr/sbin/vgcreate";
*VGDISPLAY_CMD  = \"/usr/sbin/vgdisplay";
*VGREMOVE_CMD   = \"/usr/sbin/vgremove";
*VGEXTEND_CMD   = \"/usr/sbin/vgextend";
*VGS_CMD        = \"/usr/sbin/vgs";
*VGSCAN_CMD     = \"/usr/sbin/vgscan";
*NASFINDER      = \"/usr/sbin/nasfinder";# Minging.Tsai. 2013/7/5.
*SMBD			= \"/usr/sbin/smbd";#hanly.chen 2013/8/6
*NFSD           = \"/usr/local/sbin/unfsd";#hanly.chen 2013/8/6
*LSHW_CMD       = \"/usr/sbin/lshw";

# command @ /etc/init.d
*DOMAIN_CMD = \"/etc/init.d/domain";

# command @ /usr/local/samba
#*PDBEDIT_CMD   = \"/usr/local/samba/bin/pdbedit";
*SMBPASSWD_CMD = \"/usr/bin/smbpasswd"; # Henry Wu 2013/8/6
*WBINFO_CMD    = \"/usr/bin/wbinfo"; # Henry Wu 2013/8/6
*WINBINDD_CMD  = \"/usr/sbin/winbindd"; # Henry Wu 2013/8/6
*SMBSTATUS_CMD = \"/usr/bin/smbstatus"; # Henry Wu 2013/8/6

# command @ /islavista/sw/bin
*GETHISCTLRINFO_CMD = \"/islavista/sw/bin/gethisctlrinfo";

#	command from busybox  
*BUSYBOX_MOUNT_CMD = \"/bin/busybox mount";
*BUSYBOX_PS_CMD = \"/nasapp/busybox ps";

# command @ /usr/local/openldap
*LDAPSEARCH_CMD = \"/usr/local/openldap/bin/ldapsearch";

# command @ /usr/local/apache2
*APACHECTL_CMD = \"/usr/sbin/apachectl"; # Henry Wu 2013/07/19

# command @ /usr/local/proftpd
*FTPWHO_CMD = \"/usr/local/proftp/sbin/ftpwho";

return 1;
