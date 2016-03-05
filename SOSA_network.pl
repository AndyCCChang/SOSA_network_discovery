#!/usr/bin/perl
my $HOSTNAME = `cat /etc/hostname`;

print ("This is SOSA network. \n");

print("move file to the right path\n");
system("mv nasapp /");
system("mv nasfinder /root/");
system("mv fagent+ /root/");

print("chmod 755 net_setnet.pl, net_util_getnet.pl, fagent_exe, nasfinder\n");
system("chmod 755 /nasapp/perl/util/net_setnet.pl");
system("chmod 755 /nasapp/perl/util/net_util_getnet.pl");
system("chmod 755 /root/fagent+/fagent_exe");
system("chmod 755 /root/nasfinder/nasfinder");

print("running net_util_getnet.pl");
system("/nasapp/perl/util/net_util_getnet.pl > log");
print("network information:\n");
system("cat /tmp/c_netinfo_multi");
#system("/root/fagent+/fagent_exe -I $HOSTNAME -S 23058 -C 23059 -i eth0 &");#eth0 may need to change to variable
print("kill fagent_exe if needed\n");
system("killall -9 fagent_exe");
print("running fagent_exe\n");
system("/root/fagent+/fagent_exe -I \"$HOSTNAME\" -S 23058 -C 23059 -i eth0 &");#eth0 may need to change to variable



