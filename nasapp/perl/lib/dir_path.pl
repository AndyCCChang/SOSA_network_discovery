#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: dir_path.pl
#  Author: Olive Huang
#  Date: 2012/11/08
#  Description:
#    Definition of dirextory path.
#########################################################################

$HOME_PATH = "/FS/homes";

# Samba
$SMB_LOCKS_PATH = "/usr/local/samba/var/locks";
$SMB_ADLOCKS_PATH = "/usr/local/samba/var/adlocks";

# LDAP
*LDAP_CACERTS_PATH   = \"/usr/local/openldap/etc/openldap/cacerts";

# PAM
#$PAM_PATH = "/etc/pam.d"; # no used

return 1;