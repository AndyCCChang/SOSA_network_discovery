#!/usr/bin/perl
#########################################################################
#    (C) Copyright Promise Technology Inc., 2012 All Rights Reserved
#  Name: bk_snap_def.pl
#  Author: Paul Chang
#  Date: 2012/11/14
#  Description:
#    Definition of snapshot function
#########################################################################

#perl
$PL_BKDOSNAPSHOT     = "/nasapp/perl/util/bk_dosnapshottask.pl";

#snapshot config
$BK_SNAP_PREFIX       = "/etc/snapshot";
$BK_SNAP_CONF         = "$BK_SNAP_PREFIX/snapshot.conf";
$BK_SNAP_MOUNTFOLDER  = "/SNAPSHOT";

#max number of snapshots
$BK_SNAP_MAXNUMBER    = 32;
#max number of snapshots of one Share Disk 
$BK_SNAP_MAXNUMBER_SD = 3;

#snapshot waiting second
$BK_SNAP_WAITING      = 30;

return 1;