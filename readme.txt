Put nasfinder, fagent+, nasapp and SOSA_network.pl in all nodes

SOSA1(running fagent), SOSA2(running nasfinder)
note: 
A. SOSA1(running fagent)'s eth0 needs to up and running.
B. SOSA1(running fagent)'s ip gateway must be set up!!


1.
SOSA1(running fagent)
#chmod 755 SOSA_network.pl
#./SOSA_network.pl
#cat /tmp/c_netinfo_multi
2.
SOSA2(running nasfinder):
chmod 755 SOSA_network.pl
#./SOSA_network.pl
//get ip information
#/root/nasfinder/nasfinder -S 23058 -C 23059 -o 0 -f /tmp/outfile
#cat /tmp/outfile
//set ip information
#/root/nasfinder/nasfinder -S 23058 -C 23059 -o 1 -n "SOSAandy3&000c2939a520&eth0,10.0.0.1,255.255.255.0,10.0.0.254,,eth1,10.0.0.2,255.255.255.0,10.0.0.254,,"

format:
"'hostname'&'MAC'&'interface0','interface0_ip','interface0_netmask','interface0_gateway',,'interface1','interface1_ip','interface1_netmask','interface1_gateway',,"

E.G.,
'hostname' = SOSAandy3
'MAC' = 000c2939a520
'interface0' = eth0
interface0_ip = 10.0.0.1
interface0_netmask = 255.255.255.0
interface0_gateway = 10.0.0.254