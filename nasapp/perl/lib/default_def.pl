#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: default_def.pl
#  Author: Fred
#  Date: 2013/04/26
#  Description:
#    Default value definition
#########################################################################

#	Global	

#	Volume(Pool), Share Disks
*DEFAULT_HOMES_SDNAME=\"homes";
*DEFAULT_SD_PERMISSION=\1;				#	0: Not set yet, 1: Deny, 2: Read Only, 3: Read write
*DEFAULT_SD_LAST_CHECK_STATUS=\2;		#	0:success ,1:fail ,2:Never checked

#	Protocols
*DEFAULT_ENABLE_SMB_VALUE=\1;			# 	0=> disable , 1 => enable
*DEFAULT_ENABLE_FTP_VALUE=\0;
*DEFAULT_ENABLE_AFP_VALUE=\0;
*DEFAULT_ENABLE_NFS_VALUE=\1;
*DEFAULT_ENABLE_WEBDAV_VALUE=\0;



return 1;
