#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: conf_path.pl
#  Author: Kylin Shih
#  Date: 2012/10/24
#  Description:
#    Definition of system file path.
#########################################################################

# Prefix definition.
*NASDATA_PATH   = \"/nasdata";
*DATA_PATH      = \"$NASDATA_PATH/config";		#Default to config
*DATA_LOG_PATH  = \"$NASDATA_PATH/log";
*CRYPTKEY_PATH  = \"$NASDATA_PATH/key";
*TIMESTAMP_FILE = \"$NASDATA_PATH/timestamp";
*TMP_PATH       = \"/tmp/";

# Time Zone Database Path
*TZDB_PATH      = \"/nasapp/usr/share/timezone";

# System
#*CONF_HOSTNAME     = \"/nasdata/config/etc/sysconfig/hostname";
*CONF_HOSTNAME     = \"/nasdata/config/etc/hostname"; #Minging.Tsai. 2013/7/2
*CONF_HOSTS        = \"/nasdata/config/etc/hosts";
#*CONF_HOSTS        = \"/etc/hosts"; #Minging.Tsai. 2013/7/4
*CONF_CRONTAB      = \"/nasdata/config/etc/crontab";
*CONF_TIMEZONE     = \"/nasdata/config/etc/timezone";
*CONF_LOCALTIME    = \"/nasdata/config/etc/localtime";
#*CONF_CLUSTER      = \"/nasdata/config/etc/cluster/cluster.conf";
*CONF_SCSI_CHANNEL = \"/proc/scsi/scsi";
*CONF_REMOTE_IIP   = \"/tmp/remote.txt";
*CONF_LOCAL_IIP    = \"/tmp/local.txt";
*CONF_NET          = \"/nasdata/config/etc/network.conf";   #network conf
*CONF_MAIL         = \"/nasdata/config/etc/maillist.conf";  # Paul Chang 2013/09/27
*CONF_SYS_STATUS   = \"/tmp/sys_status";     # Paul Chang 2013/10/03
*CONF_LOADAVG      = \"/proc/loadavg";
*CONF_MEMINFO      = \"/proc/meminfo";
*CONF_UPTIME       = \"/proc/uptime";
*CONF_NET_DEV      = \"/proc/net/dev";
*CONF_NET_SNMP     = \"/proc/net/snmp";


#Network 
*BOND_PATH		   = \"/proc/net/bonding/";#Minging.Tsai. 2013/7/1
*NETWORK_SCRIPT	   = \"/etc/init.d/network";#Minging.Tsai. 2013/7/1
#*NETWORK_SCRIPT_10G = \"/etc/init.d/network_10G";#Minging.Tsai. 2013/9/3

# Account
*CONF_DOMAIN       = \"/nasdata/config/etc/domain";
*CONF_GROUP        = \"/etc/group";
*CONF_GROUP_SRC    = \"/etc/group.src";#Minging.Tsai. 2013/8/27.
*CONF_GSHADOW      = \"/etc/gshadow";
*CONF_KRB5         = \"/nasdata/config/etc/krb5.conf";
*CONF_KDC          = \"/nasdata/config/etc/kdc.conf";
*CONF_PASSWD       = \"/etc/passwd";
*CONF_PASSWD_SRC   = \"/etc/passwd.src";#Minging.Tsai. 2013/8/27.
*CONF_SHADOW       = \"/etc/shadow";
*DOMAIN_UPDATE_COUNTER      = \"/tmp/domain_update_counter";

# Account to system lock
*CONF_ADDGRP_LOCK  = \"/tmp/lock.addgrp";
*CONF_ADDUSER_LOCK = \"/tmp/lock.adduser";
*CONF_DELGRP_LOCK  = \"/tmp/lock.delgrp";
*CONF_DELUSER_LOCK = \"/tmp/lock.deluser";

# Account-AD
*AD_SMB_KRB5            = \"/var/locks/smb_krb5";  # Henry Wu 2013/8/6
*AD_WINBINDD_CACKE      = \"/var/locks/winbindd_cache.tdb";  # Henry Wu 2013/8/6
*AD_WINBINDD_IDMAP      = \"/var/locks/winbindd_idmap.tdb";  # Henry Wu 2013/8/6
*AD_WINBINDD_PRIVILEGE  = \"/var/locks/winbindd_privileged";  # Henry Wu 2013/8/6
*AD_NETSAMLOGON_CACHE   = \"/var/locks/netsamlogon_cache.tdb";  # Henry Wu 2013/8/6
*AD_MUTEX               = \"/var/locks/mutex.tdb";  # Henry Wu 2013/8/6
*AD_NAMELIST            = \"/var/locks/namelist.debug";  # Henry Wu 2013/8/6

# Account-LDAP
#*LDAP_PAM_LDAP_CONF     = \"/etc/pam_ldap.conf";
*LDAP_PAM_LDAP_CONF     = \"/nasdata/config/etc/pam_ldap.conf";# Minging.Tsai. 2013/8/7
*LDAP_SYSTEM_AUTH       = \"/etc/pam.d/system-auth";
#*LDAP_NSLCD_CONF        = \"/etc/nslcd.conf";
*LDAP_NSLCD_CONF        = \"/nasdata/config/etc/nslcd.conf";# Minging.Tsai. 2013/8/7
*LDAP_CONF              = \"/nasdata/config/etc/openldap/ldap.conf";#Minging.Tsai. 2013/8/15
*LDAP_UPDATE_COUNTER    = \"/tmp/ldap_update_counter_t";
*LDAP_UPDATE_REMAIN     = \"/tmp/ldap_update_remain_t";
*LDAP_UPDATE_STATUS     = \"/tmp/ldap_update_status";

# NTP
*NTP_CONF = \"/nasdata/config/etc/ntp.conf";

# Backup
*RSYNC_PASSWD = \"/nasdata/config/etc/rsync.passwd";
*RSYNCD_CONF  = \"/etc/rsyncd.conf";
*RSYNCD_PID   = \"/var/run/rsyncd.pid";
*SSHD_CONF    = \"/etc/sshd_config";
*SSHD_PID     = \"/var/run/sshd.pid";

# Samba
*SMB_CONF        = \"/nasdata/config/etc/samba/smb.conf";# Minging.Tsai. 2013/8/8
#*SMB_PASSWD      = \"/nasdata/config/usr/local/samba/private/smbpasswd"; 
*SMB_PASSWD      = \"/nasdata/config/etc/smbpasswd"; #Minging.Tsai. 2014/2/5.
#*SMB_SECRETS_TDB = \"/nasdata/config/usr/local/samba/private/secrets.tdb"; # no used
#*SMB_OPTION      = \"/etc/smboption"; #Olive Huang 2013/9/18 
*SMB_OPTION      = \"/nasdata/config/etc/smboption";

# afp
*AFP_VOL_CONF = \"/nasdata/config/usr/local/netatalk/etc/netatalk/AppleVolumes.default";
*AFP_MSG_CONF = \"/nasdata/config/usr/local/netatalk/etc/netatalk/afpd.conf";

# ftp
*FTP_CONF        = \"/nasdata/config/etc/proftpd.conf";

#Apache webdav
*APACHE_CONF        = \"/etc/httpd/conf/httpd.conf";
*WEBDAV_CONF        = \"/nasdata/config/usr/local/apache2/conf/extra/web_dav.conf";

#Apache others
#*VHOSTS_CONF = \"/usr/local/apache2/conf/extra/vhosts.conf"; # no used

# nfs
*NFS_CONF        = \"/nasdata/config/etc/exports";

# DNS
*CONF_NSSWITCH = \"/nasdata/config/etc/nsswitch.conf";
*CONF_RESOLV   = \"/nasdata/config/etc/resolv.conf";

# Protocol
*PRO_CONF_PATH      = \"/nasdata/config/etc/server";
*PRO_CONF_SMB       = \"$PRO_CONF_PATH/smb";
*PRO_CONF_NFS       = \"$PRO_CONF_PATH/nfs";
*PRO_CONF_AFP       = \"$PRO_CONF_PATH/afp";
*PRO_CONF_FTP       = \"$PRO_CONF_PATH/ftp";
*PRO_CONF_WEBDAV    = \"$PRO_CONF_PATH/webdav";
*PRO_RELOAD_ALL     = \"$PRO_CONF_PATH/reload.all";
*PRO_RELOAD_RESTART = \"$PRO_CONF_PATH/reload.restart";
*PRO_RELOAD_SMB     = \"$PRO_CONF_PATH/reload.smb";
*PRO_RELOAD_NFS     = \"$PRO_CONF_PATH/reload.nfs";
*PRO_RELOAD_AFP     = \"$PRO_CONF_PATH/reload.afp";
*PRO_RELOAD_FTP     = \"$PRO_CONF_PATH/reload.ftp";
*PRO_RELOAD_WEBDAV  = \"$PRO_CONF_PATH/reload.webdav";
*PRO_NETWORKBIN     = \"$PRO_CONF_PATH/networkbin";
*PRO_CONF_KEEPALIVED = \"$PRO_CONF_PATH/keepalived";
# eth1 IP
*ETH1IP_LOCAL  = \"/tmp/local.txt";
*ETH1IP_REMOTE = \"/tmp/remote.txt";

# PAM
*PAM_SMB      = \"/etc/pam.d/samba";
*PAM_NETATALK = \"/etc/pam.d/netatalk";
*PAM_FTP      = \"/etc/pam.d/ftp";
# *PAM_OTHER    = \"/etc/pam.d/other"; # no used

# Snapshot
*CONF_SNAPSHOT            = \"/nasdata/config/etc/snapshot/snapshot.conf";
#*SNAPSHOT_CHECK_REMAIN    = \"/tmp/snapshot_check_remain_t";--snapshot pending 2013/4/24 olive huang

# Alert Agent
*ALERT_CHECK_REMAIN    = \"/tmp/alert_check_remain_t";

#QUOTA
*CONF_QUOTAREF_LOCK = \"/tmp/lock.quotaref";
*CONF_QUOTAAPY_LOCK = \"/tmp/lock.quotaapy";

#reload protocol lock
*CONF_RELOAD_PROTOCOL_LOCK = \"/tmp/lock.reloadprotocol";

#apply permission lock
*CONF_PERMAPY_LOCK = \"/tmp/lock.permapy";

#clear log lock
*CONF_CLEAR_LOG_LOCK = \"/tmp/lock.clearlog";

# SRC
*NASDATA_SRC_PATH           = \"/tmp/nasdata_src";
*NASDATA_SRC_CONFIG_PATH    = \"/tmp/nasdata_src/config";
*SRC_NFS_CONF               = \"$NASDATA_SRC_CONFIG_PATH/etc/exports";
*SRC_PASSWD                 = \"$NASDATA_SRC_CONFIG_PATH/etc/passwd";
*SRC_SHADOW                 = \"$NASDATA_SRC_CONFIG_PATH/etc/shadow";
*SRC_GROUP                  = \"$NASDATA_SRC_CONFIG_PATH/etc/group";
*SRC_GSHADOW                = \"$NASDATA_SRC_CONFIG_PATH/etc/gshadow";
*SRC_LDAP_NSLCD_CONF        = \"$NASDATA_SRC_CONFIG_PATH/etc/nslcd.conf.src";
*SRC_PAM_LDAP_CONF          = \"$NASDATA_SRC_CONFIG_PATH/etc/pam_ldap.conf";
*SRC_LDAP_SYSTEM_AUTH       = \"$NASDATA_SRC_CONFIG_PATH/etc/pam.d/system-auth";
*SRC_AFP                    = \"$NASDATA_SRC_CONFIG_PATH/etc/server/afp";
*SRC_FTP                    = \"$NASDATA_SRC_CONFIG_PATH/etc/server/ftp";
*SRC_NFS                    = \"$NASDATA_SRC_CONFIG_PATH/etc/server/nfs";
*SRC_SMB                    = \"$NASDATA_SRC_CONFIG_PATH/etc/server/smb";
*SRC_WEBDAV                 = \"$NASDATA_SRC_CONFIG_PATH/etc/server/webdav";
*SRC_APACHE_CONF            = \"$NASDATA_SRC_CONFIG_PATH/usr/local/apache2/conf/httpd.conf";
*SRC_WEBDAV_CONF            = \"$NASDATA_SRC_CONFIG_PATH/usr/local/apache2/conf/extra/web_dav.conf";
*SRC_AFP_VOL_CONF           = \"$NASDATA_SRC_CONFIG_PATH/usr/local/netatalk/etc/netatalk/AppleVolumes.default";
*SRC_AFP_MSG_CONF           = \"$NASDATA_SRC_CONFIG_PATH/usr/local/netatalk/etc/netatalk/afpd.conf";
*SRC_LDAP_CONF              = \"$NASDATA_SRC_CONFIG_PATH/usr/local/openldap/etc/openldap/ldap.conf";
*SRC_FTP_CONF               = \"/etc/proftpd.src";
*SRC_SMBPASSWD              = \"$NASDATA_SRC_CONFIG_PATH/etc/smbpasswd"; # Minging.Tsai. 2014/2/5. 
*SRC_SMB_CONF               = \"$NASDATA_SRC_CONFIG_PATH/etc/samba/smb.conf.src";

# Database File
*CONF_DB_USER   = \"$DATA_PATH/etc/user.db";
*CONF_DB_FS     = \"$DATA_PATH/etc/fs.db";
*CONF_DB_LOG    = \"$DATA_PATH/etc/naslog.db";
*CONF_DB_UM_LOG = \"$DATA_PATH/etc/umnaslog.db";

#	Cache Files
*CACHE_SYS_LIMITS = \"/tmp/nas_limits";
*CACHE_NET_FLOW   = \"/tmp/netflow";

#   Helios conf Files
*HELIOS_CONF = \"$DATA_PATH/etc/helios.conf";
*JOIN_CONF = \"$DATA_PATH/etc/join_info.conf";


return 1;
