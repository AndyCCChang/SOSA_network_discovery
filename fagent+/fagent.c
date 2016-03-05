/*******************************************************************************
 * Filename    : fagent.c
 * Description : Finder agent implementation
 *
 * Created on  : 06/10/04
 * CVS Version : $Id: fagent.c 5576 2013-01-30 08:32:47Z henry.wu $
 *
 * (C) Copyright Promise Technology Inc., 2004
 * All Rights Reserved
 ******************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <syslog.h>
#include <unistd.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <sys/types.h>
#include <fcntl.h>

#include "fagent.h"
//#include "crond_check.h"
#define _PATH_PROCNET_DEV               "/proc/net/dev"

#define VERSION  "v1.4"
#define MSGKEY   "Promise&"
#define BUFLEN	 1400
//TODO: to redefine the corresponding path
#define _PATH_TMP_NETINFO			"/tmp/c_netinfo_multi"
//#define _PATH_PERL_GETNETDEVIP		"/promise/util/getnetdevip.pl"
#define _PATH_PERL_GETNETDEVIP		"/nasapp/perl/util/net_getdevip.pl" //Minging.Tsai. 2013/7/1.
//#define _PATH_PERL_GETNETINFO		"/promise/util/c_getnetinfo_multi.pl"
#define _PATH_PERL_GETNETINFO		"/nasapp/perl/util/net_util_getnet.pl"
//#define _PATH_PERL_SETHOSTNAME		"/promise/util/sethostname.pl"
#define _PATH_PERL_SETHOSTNAME	"/nasapp/perl/sys_sethostname.pl"
//#define _PATH_SH_SETNET				"/usr/sbin/setnet"
#define _PATH_SH_SETNET				"/nasapp/perl/util/net_setnet.pl" //Minging.Tsai. 2013/7/4.

/* network (big endian) byte order */
static const u_int8_t your_ip[4] = { 192, 168, 200, 80 };

#if 0
static const u_int8_t magic_cookie[4] = { 99, 130, 83, 99 };

static const u_int8_t test_server_data[] = {
	/* network (big endian) byte order */
	BOOTP_OPTION_NETMASK,  4, 255, 255, 255, 0,
	BOOTP_OPTION_GATEWAY,  4, 192, 168, 200, 31,
	BOOTP_OPTION_DNS,      8, 198, 235, 216, 110,   204, 101, 251, 1,
	BOOTP_OPTION_HOSTNAME, 5, 't', 'e', 's', 't', '2',
	BOOTP_OPTION_DOMAIN,  11, 's', 'u', 'p', 'e', 'r', 'b', 't', '.',
	'c', 'o', 'm',
};
#endif

int debug;
int interfaceflag = 0;

int login(char *rev_str) {
	char username[32], passwd[32];
	int i;

//syslog (LOG_DEBUG, "LOGIN: %s", rev_str);

	for (i=0; i<strlen(rev_str); i++) {
		if ( rev_str[i] == '&' ) {
			strncpy(passwd, rev_str+i+1, strlen(rev_str)-i-1 );
			passwd[strlen(rev_str)-i-1] = '\0';
			break;
		}
		username[i] = rev_str[i];
	}
	username[i] = '\0';

	//syslog (LOG_DEBUG, "LOGIN: %s %s", username, passwd);

	if ( check_auth( username, passwd ) ) {
		return 1;
	} else {
		return 0;
	}

}

int getnetinfo(char *newformat, char *miface)
{
	FILE *fp;
	char tempstr[BUFLEN];

	fp = fopen(_PATH_TMP_NETINFO,"r");
	if( fp == NULL ) {
		//printf("fp==NULL\n");
		return 0;
	}

	if(miface) {
		strcpy(newformat,miface);
		strcat(newformat,"&");
	}	
	else
		strcpy(newformat,"NAV+&");

	memset(tempstr, 0, sizeof(tempstr));
	while ( !feof(fp) ) {
		fscanf(fp,"%s",tempstr);
		strcat(newformat,tempstr);
		break;
	}

	fclose(fp);
	return 1;
}

void error(const char *msg) {
	//syslog(LOG_ERR, "%s: %s", msg, strerror(errno));
	exit(EXIT_FAILURE);
}

void usage() {
	fprintf(stderr,
	        "Usage: fagent+ [-s] [-i (INTERFACE_NAME | INTERFACE_ADDR)] [-g GROUP]\n"
	        "\t[-t TTL] [-S PORT] [-C PORT] [-d]\n");
	exit(EXIT_FAILURE);
}


/* Code stolen from pump -- dhcp.c -- (C) RedHat, Inc */
/* See also RFC 1533 */

void debug_bootp_packet(bootp_packet *breq, int breqlen) {
	char vendor[28], vendor2[28];
	int i;
	struct in_addr address;
	unsigned char *vndptr;
	unsigned char option, length;

	memset(&address, 0, sizeof(address));

	//syslog (LOG_DEBUG, "opcode: %i", breq->opcode);
	//syslog (LOG_DEBUG, "hw: %i", breq->hw);
	//syslog (LOG_DEBUG, "hwlength: %i", breq->hwlength);
	//syslog (LOG_DEBUG, "hopcount: %i", breq->hopcount);
	//syslog (LOG_DEBUG, "xid: 0x%08x", breq->xid);
	//syslog (LOG_DEBUG, "secs: %i", breq->secs);
	//syslog (LOG_DEBUG, "flags: 0x%04x", breq->flags);

	memcpy(&address.s_addr, breq->ciaddr, 4);
	//syslog (LOG_DEBUG, "ciaddr: %s", inet_ntoa (address));

	memcpy(&address.s_addr, breq->yiaddr, 4);
	//syslog (LOG_DEBUG, "yiaddr: %s", inet_ntoa (address));

	memcpy(&address.s_addr, breq->server_ip, 4);
	//syslog (LOG_DEBUG, "server_ip: %s", inet_ntoa (address));

	memcpy(&address.s_addr, breq->bootp_gw_ip, 4);
	//syslog (LOG_DEBUG, "bootp_gw_ip: %s", inet_ntoa (address));

	//syslog (LOG_DEBUG, "hwaddr: %02X:%02X:%02X:%02X:%02X:%02X",
	//        breq->hwaddr[0], breq->hwaddr[1], breq->hwaddr[2],
	//        breq->hwaddr[3], breq->hwaddr[4], breq->hwaddr[5]);
	//syslog (LOG_DEBUG, "servername: %s", breq->servername);
	//syslog (LOG_DEBUG, "bootfile: %s", breq->bootfile);

#if 0	//DHCP_VENDOR_LENGTH is 1 now
	vndptr = breq->vendor;
	sprintf (vendor, "0x%02x 0x%02x 0x%02x 0x%02x",
	         *vndptr++, *vndptr++, *vndptr++, *vndptr++);
	syslog (LOG_DEBUG, "vendor: %s", vendor);


	while ((void *) vndptr < ((void *)breq) + breqlen) {
		option = *vndptr++;
		if (option == 0xFF) {
			sprintf (vendor, "0x%02x", option);
			break;
		} else if (option == 0x00) {
			for (i = 1;
			        (*vndptr == 0x00) && (void *)vndptr < ((void *)breq) + breqlen;
			        i++, vndptr++);
			sprintf (vendor, "0x%02x x %i", option, i);
		} else {
			length = *vndptr++;
			sprintf (vendor, "%3u %3u", option, length);
			for (i = 0; i < length; i++) {
				if (strlen (vendor) > sizeof(vendor) - 6) {
					syslog (LOG_DEBUG, "vendor: %s", vendor);
					strcpy (vendor, "++++++");
				}
				snprintf (vendor2, sizeof(vendor2), "%s 0x%02x",
				          vendor, *vndptr++);
				vendor2[sizeof(vendor2) - 1] = '\0';
				strncpy(vendor, vendor2, sizeof(vendor));
				vendor[sizeof(vendor) - 1] = '\0';
			}
		}

		syslog (LOG_DEBUG, "vendor: %s", vendor);
	}
#endif
}

void process_bootp_packet(bootp_packet *breq, int breqlen,
                          struct pumpNetIntf *intf) {
	int i;
	u_int8_t * chptr;
	u_int8_t option, length;

	if (debug)
		debug_bootp_packet(breq, breqlen);

	memset(intf, 0, sizeof(*intf));
	memcpy(&intf->ip, &breq->yiaddr, 4);
	intf->set |= PUMP_INTFINFO_HAS_IP;

	chptr = breq->vendor;
#if 0	//DHCP_VENDOR_LENGTH is 1 now
	chptr += 4;
#endif
#if 0	//not enough space for option (because sizeof(bootfile) is 1239)
	while (*chptr != 0xFF &&
	        (void *) chptr < ((void *) breq) + breqlen) {
		option = *chptr++;
		if (!option) continue;
		length = *chptr++;

		switch (option) {
		case BOOTP_OPTION_DNS:
			intf->numDns = 0;
			for (i = 0; i < length; i += 4) {
				if (intf->numDns < MAX_DNS_SERVERS) {
					memcpy(&intf->dnsServers[intf->numDns++], chptr + i, 4);
					syslog(LOG_DEBUG, "dnsServers[%i]: %s", i/4,
					       inet_ntoa(*(struct in_addr *)&intf->dnsServers[i/4]));
				}
			}
			intf->set |= PUMP_NETINFO_HAS_DNS;
			syslog (LOG_DEBUG, "intf: numDns: %i", intf->numDns);
			break;

		case BOOTP_OPTION_NETMASK:
			memcpy(&intf->netmask, chptr, 4);
			intf->set |= PUMP_INTFINFO_HAS_NETMASK;
			syslog(LOG_DEBUG, "intf: netmask: %s",
			       inet_ntoa(*(struct in_addr *)&intf->netmask));
			break;

		case BOOTP_OPTION_NISDOMAIN:
			if ((intf->nisDomain = malloc(length + 1))) {
				memcpy(intf->nisDomain, chptr, length);
				intf->nisDomain[length] = '\0';
				intf->set |= PUMP_NETINFO_HAS_NISDOMAIN;
				syslog (LOG_DEBUG, "intf: nisDomain: %s", intf->nisDomain);
			}
			break;

		case BOOTP_OPTION_DOMAIN:
			if ((intf->domain = malloc(length + 1))) {
				memcpy(intf->domain, chptr, length);
				intf->domain[length] = '\0';
				intf->set |= PUMP_NETINFO_HAS_DOMAIN;
				syslog (LOG_DEBUG, "intf: domain: %s", intf->domain);
			}
			break;

		case BOOTP_OPTION_BROADCAST:
			memcpy(&intf->broadcast, chptr, 4);
			intf->set |= PUMP_INTFINFO_HAS_BROADCAST;
			syslog (LOG_DEBUG, "intf: broadcast: %s",
			        inet_ntoa(*(struct in_addr *)&intf->broadcast));
			break;

		case BOOTP_OPTION_GATEWAY:
			memcpy(&intf->gateway, chptr, 4);
			intf->set |= PUMP_NETINFO_HAS_GATEWAY;
			syslog (LOG_DEBUG, "intf: gateway: %s",
			        inet_ntoa(*(struct in_addr *)&intf->gateway));
			break;

		case BOOTP_OPTION_HOSTNAME:
			if ((intf->hostname = malloc(length + 1))) {
				memcpy(intf->hostname, chptr, length);
				intf->hostname[length] = '\0';
				intf->set |= PUMP_NETINFO_HAS_HOSTNAME;
				syslog (LOG_DEBUG, "intf: hostname: %s", intf->hostname);
			}
			break;

		case BOOTP_OPTION_BOOTFILE:
			/* we ignore this right now */
			break;

		case DHCP_OPTION_LOGSRVS:
			intf->numLog = 0;
			for (i = 0; i < length; i += 4) {
				if (intf->numLog < MAX_LOG_SERVERS) {
					memcpy(&intf->logServers[intf->numLog++], chptr + i, 4);
					syslog(LOG_DEBUG, "intf: logServers[%i]: %s", i/4,
					       inet_ntoa(*(struct in_addr *)&intf->logServers[i/4]));
				}
			}
			intf->set |= PUMP_NETINFO_HAS_LOGSRVS;
			syslog (LOG_DEBUG, "intf: numLog: %i", intf->numLog);
			break;

		case DHCP_OPTION_LPRSRVS:
			intf->numLpr = 0;
			for (i = 0; i < length; i += 4) {
				if (intf->numLpr < MAX_LPR_SERVERS) {
					memcpy(&intf->lprServers[intf->numLpr++], chptr + i, 4);
					syslog(LOG_DEBUG, "intf: lprServers[%i]: %s", i/4,
					       inet_ntoa(*(struct in_addr *)&intf->lprServers[i/4]));
				}
			}
			intf->set |= PUMP_NETINFO_HAS_LPRSRVS;
			syslog (LOG_DEBUG, "intf: numLpr: %i", intf->numLpr);
			break;

		case DHCP_OPTION_NTPSRVS:
			intf->numNtp = 0;
			for (i = 0; i < length; i += 4) {
				if (intf->numNtp < MAX_NTP_SERVERS) {
					memcpy(&intf->ntpServers[intf->numNtp++], chptr + i, 4);
					syslog(LOG_DEBUG, "intf: ntpServers[%i]: %s", i/4,
					       inet_ntoa(*(struct in_addr *)&intf->ntpServers[i/4]));
				}
			}
			intf->set |= PUMP_NETINFO_HAS_NTPSRVS;
			syslog (LOG_DEBUG, "intf: numNtp: %i", intf->numNtp);
			break;

		case DHCP_OPTION_XFNTSRVS:
			intf->numXfs = 0;
			for (i = 0; i < length; i += 4) {
				if (intf->numXfs < MAX_XFS_SERVERS) {
					memcpy(&intf->xfntServers[intf->numXfs++],
					       chptr + i, 4);
					syslog(LOG_DEBUG, "intf: xfntServers[%i]: %s", i/4,
					       inet_ntoa(*(struct in_addr *)
					                 &intf->xfntServers[i/4]));
				}
			}
			intf->set |= PUMP_NETINFO_HAS_XFNTSRVS;
			syslog (LOG_DEBUG, "intf: numXfs: %i", intf->numXfs);
			break;

		case DHCP_OPTION_XDMSRVS:
			intf->numXdm = 0;
			for (i = 0; i < length; i += 4) {
				if (intf->numXdm < MAX_XDM_SERVERS) {
					memcpy(&intf->xdmServers[intf->numXdm++], chptr + i, 4);
					syslog(LOG_DEBUG, "intf: xdmServers[%i]: %s", i/4,
					       inet_ntoa(*(struct in_addr *)&intf->xdmServers[i/4]));
				}
			}
			intf->set |= PUMP_NETINFO_HAS_XDMSRVS;
			syslog (LOG_DEBUG, "intf: numXdm: %i", intf->numXdm);
			break;

		case DHCP_OPTION_OVERLOAD:
			/* FIXME: we should pay attention to this */
			break;
		}

		chptr += length;
	}
#endif
}

static char* skip_whitespace(char *s)
{
	while (*s == ' ' || *s == '\t') ++s;

	return s;
}

static char *get_name(char *name, char *p)
{
	/* Extract <name> from nul-terminated p where p matches
	 * <name>: after leading whitespace.
	 * If match is not made, set name empty and return unchanged p
	 */
	char *nameend;
	char *namestart = skip_whitespace(p);

	nameend = namestart;
	while (*nameend && *nameend != ':' && !isspace(*nameend))
		nameend++;
	if (*nameend == ':') {
		if ((nameend - namestart) < IFNAMSIZ) {
			memcpy(name, namestart, nameend - namestart);
			name[nameend - namestart] = '\0';
			p = nameend;
		} else {
			/* Interface name too large */
			name[0] = '\0';
		}
	} else {
		/* trailing ':' not found - return empty */
		name[0] = '\0';
	}
	return p + 1;
}

static int if_readlist_proc(char *target)
{
	FILE *fh;
	char buf[512];
	int err;

	fh = fopen(_PATH_PROCNET_DEV, "r");
	if (!fh) {
		return -1;
	}
	fgets(buf, sizeof buf, fh);     /* eat line */
	fgets(buf, sizeof buf, fh);

	err = 0;
	while (fgets(buf, sizeof buf, fh)) {
		char *s, name[128];

		s = get_name(name, buf);
		if (target && !strcmp(target, name))
			break;
	}
	if (ferror(fh)) {
		err = -1;
	}
	fclose(fh);
	return err;
}

int main(int argc, char *argv[]) {
	int sock, intfsock;
	int opt;
	struct sockaddr_in addr, foreignaddr;
	socklen_t foreignaddrlen;
	int len;
	char addrtext[32], addrtext2[32], *paddrtext;
	struct ip_mreqn mreq;
	char *miface, *mifacename;
#define MAX_IFS 20
	struct ifreq ifaces[MAX_IFS];
	int mifaceind;
	u_int8_t mifacehwaddr[IFHWADDRLEN];
	struct in_addr mifaceaddr;
	char servername[64] = MSGKEY;
	int server;
	//int serverport = 49152;
	//int clientport = 49153;
	int serverport = 23058;
	int clientport = 23059;
	bootp_packet bp, br;
	struct pumpNetIntf bi;
	int vendorlen;
	time_t time0;

	/*
	 * See ftp://ftp.microsoft.com/bussys/winsock/ms-ext/multcast.txt
	 * on the use of multicast addresses
	 */
	char *multiaddr = "225.0.0.1";
	int multittl = 31;
	char *filename = NULL;

	char ident[8], recvalue[BUFLEN];
	int result;
	char command[BUFLEN];
	char netinfo[BUFLEN];
	int bonding = 0;

	//miface = NULL;
	miface = "eth0";
	mifacename = NULL;
	mifaceind = 0;
	memset(&mifaceaddr, 0, sizeof(mifaceaddr));
	mifaceaddr.s_addr = htonl(INADDR_ANY);
	memset(&mifacehwaddr, 0, sizeof(mifacehwaddr));

	server = 0;
	debug = 0;
	while ((opt=getopt(argc,argv,"si:g:t:o:S:C:I:d:v")) != EOF) {
		switch(opt) {
		case 's':
			server = 1;
			break;

		case 'i':
			miface = optarg;
			break;

		case 'g':
			multiaddr = strdup(optarg);
			break;

		case 't':
			multittl = strtol(optarg, NULL, 0);
			if (errno)
				error("TTL must be a number");
			break;

		case 'S':
			serverport = strtol(optarg, NULL, 0);
			if (errno)
				error("SERVER_PORT must be a number");
			break;

		case 'C':
			clientport = strtol(optarg, NULL, 0);
			if (errno)
				error("CLIENT_PORT must be a number");
			break;

		case 'I':
			strcat(servername,strdup(optarg));
			break;

		case 'd':
			debug = 1;
			break;

		case 'v':
			printf("Version:%s\n", VERSION);
			exit(0);

		default:
			usage();
		}
	}

	openlog("fagent+", LOG_PID | LOG_NDELAY | (debug ? LOG_PERROR : 0),
	        LOG_DAEMON);

	sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (sock < 0)
		error("socket");

	if (miface != NULL) {
		if (!if_readlist_proc(miface)) {
			mifacename = miface;
			struct ifreq ifr;
			intfsock = socket(AF_INET, SOCK_DGRAM, 0);
			//intfsock = socket(PF_INET, SOCK_DGRAM, IPPROTO_IP);
			strncpy(ifr.ifr_name, miface, sizeof(ifr.ifr_name));
			if (ioctl(intfsock, SIOCGIFHWADDR, &ifr) < 0) {
				error("ioctl SIOCGIFHWADDR");
			}
			memcpy(&mifacehwaddr, &ifr.ifr_hwaddr.sa_data, IFHWADDRLEN);
			//unsigned char *s = &mifacehwaddr;
			//printf("%x %x %x %x %x %x\n", s[0],s[1],s[2],s[3],s[4],s[5]);
			ifr.ifr_addr.sa_family = AF_INET;
			if (ioctl(intfsock, SIOCGIFADDR, &ifr) < 0) {
				char bondip_file[16] = {0};
				strcat(bondip_file, "/tmp/bondip_");
				strcat(bondip_file, miface);
				//printf("not ip!!it is bond slave get ip from perl script\n");
				sprintf(command, _PATH_PERL_GETNETDEVIP" %s > %s", miface, bondip_file);
				system(command);
				FILE *fp = fopen(bondip_file, "r");
				if (fp) {
					unsigned char *i = &mifaceaddr;
					while ( !feof(fp) ) {
						fscanf(fp,"%d.%d.%d.%d", &i[0], &i[1], &i[2], &i[3]);
					}
					fclose(fp);
					unlink(bondip_file);
				} else {
					error("error get ip\n");
				}

				//error("ioctl SIOCGIFADDR");
			} else {
				mifaceaddr = ((struct sockaddr_in *)&(ifr.ifr_addr))->sin_addr;
			}
			//s = &mifaceaddr;
			//printf("%d %d %d %d\n", s[0],s[1],s[2],s[3]);
			close(intfsock);
		}
	}

#if 0
again:
	if (miface != NULL) {
		struct ifconf ifconfig;
		int i;

		ifconfig.ifc_len = sizeof(ifaces);
		ifconfig.ifc_req = (struct ifreq *)&ifaces;

		if (ioctl(sock, SIOCGIFCONF, &ifconfig) < 0)
			error("ioctl SIOCGIFCONF");

		for (i = 0; i < ifconfig.ifc_len / sizeof(struct ifreq); i++) {
			printf("ifname %s\n", ifaces[i].ifr_name);
			ifaces[i].ifr_addr.sa_family = AF_INET;
			if (ioctl(sock, SIOCGIFADDR, &ifaces[i]) < 0)
				error("ioctl SIOCGIFADDR");
		}

		if (strchr(miface, '.') != NULL) {
			if (!inet_aton(miface, &addr.sin_addr))
				error("inet_aton: multicast interface address");
			for (i = 0; i < ifconfig.ifc_len / sizeof(struct ifreq); i++)
				if (((struct sockaddr_in *)
				        &(ifaces[i].ifr_addr))->sin_addr.s_addr
				        == addr.sin_addr.s_addr)
					mifaceind = i + 1;
		} else {
			for (i = 0; i < ifconfig.ifc_len / sizeof(struct ifreq); i++)
				if (!strcmp(ifaces[i].ifr_name, miface))
					mifaceind = i + 1;
		}

		if (mifaceind) {
			struct ifreq ifr;
			mifaceaddr = ((struct sockaddr_in *)
			              &(ifaces[mifaceind - 1].ifr_addr))->sin_addr;
			mifacename = ifaces[mifaceind - 1].ifr_name;

			strncpy(ifr.ifr_name, mifacename, sizeof(ifr.ifr_name));
			ifr.ifr_addr.sa_family = AF_INET;
			if (ioctl(sock, SIOCGIFHWADDR, &ifr) < 0)
				error("ioctl SIOCGIFHWADDR");

			memcpy(&mifacehwaddr, &ifr.ifr_hwaddr.sa_data, IFHWADDRLEN);
			unsigned char *s = &mifacehwaddr;
			//printf("%x %x %x %x %x %x\n", s[0],s[1],s[2],s[3],s[4],s[5]);
		} else {
			miface = "bond0";
			bonding = 1;
			goto again;
		}
	}

	if (bonding)
		mifaceind = 0;
#endif
	if (mifacename == NULL)
		mifacename = "default";

	memset(&bp, 0, sizeof(bp));
	bp.opcode = (server ? 2 : 1); // client will request first
	bp.hw = 1;                    // ethernet
	bp.hwlength = IFHWADDRLEN;    // length of the hardware address
	bp.hopcount = 255;            // can be used by a proxy server,
	// shouldn't affect multicast
	bp.xid = htonl(0x12345678);
	bp.secs = htons(0);
	bp.flags = htons(0);
	if (server) {
		memset(&bp.ciaddr, 0, 4);
		memcpy(&bp.yiaddr, &your_ip, 4);
		memcpy(&bp.server_ip, &mifaceaddr, 4);
	} else {
		memcpy(&bp.ciaddr, &mifaceaddr, 4);
		memset(&bp.yiaddr, 0, 4);
		memset(&bp.server_ip, 0, 4);
	}

	memset(&bp.bootp_gw_ip, 0, 4);
	memcpy(&bp.hwaddr, &mifacehwaddr, sizeof(mifacehwaddr));
	strncpy((char *)&bp.servername, servername, sizeof(bp.servername));

#if 0
	memcpy(&bp.vendor, &magic_cookie, 4);
	vendorlen = 4;
	if (server) {
		memcpy(((void *)&bp.vendor) + 4, &test_server_data,
		       sizeof(test_server_data));
		vendorlen += sizeof(test_server_data);
	};
#else
	vendorlen = 0;
#endif
	bp.vendor[vendorlen++] = 0xFF;

// Print
//	fprintf(stdout, "Server Name = %s\n", servername);
//	fprintf(stdout, "bp.hwaddr = %d %d %d %d %d %d\n",
//			bp.hwaddr[0], bp.hwaddr[1], bp.hwaddr[2], bp.hwaddr[3], bp.hwaddr[4], bp.hwaddr[5]);

	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	/* 67 -- server, 68 -- client */
	if (server)
		addr.sin_port = htons(serverport);
	else
		addr.sin_port = htons(clientport);

	// addr.sin_addr = mifaceaddr;
	addr.sin_addr.s_addr = htonl(INADDR_ANY);

	if ((paddrtext = (char *)inet_ntop(AF_INET, &addr.sin_addr,
	                                   addrtext, sizeof(addrtext))) == NULL)
		error("inet_ntop");

	//syslog(LOG_INFO, "Local address %s, port %d\n",
	//       paddrtext, ntohs(addr.sin_port));

	opt = 1;
	if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0)
		error("setsockopt SO_REUSEADDR");

#if 0
	// see "man 4 ip", "man 7 socket" on SO_BROADCAST -- the option is discouraged
	if (server) {
		opt = 1;
		if (setsockopt(sock, SOL_SOCKET, SO_BROADCAST,
		               &opt, sizeof(opt)) < 0)
			error("setsockopt SO_BROADCAST");
	}
#endif

	if (bind(sock, (struct sockaddr *) &addr, sizeof(addr)) < 0)
		error("bind");

	if (!inet_aton(multiaddr, &mreq.imr_multiaddr))
		error("inet_aton");

#if 1
	mreq.imr_address = mifaceaddr;
	mreq.imr_ifindex = mifaceind;
#elif 0
	mreq.imr_address = mifaceaddr;
	mreq.imr_ifindex = 0;
#else
	mreq.imr_address.s_addr = htonl(INADDR_ANY);
	mreq.imr_ifindex = 0;
	mifacename = "default";
#endif

	if (setsockopt(sock, SOL_IP, IP_ADD_MEMBERSHIP, &mreq, sizeof(mreq)) < 0)
		error("setsockopt IP_ADD_MEMBERSHIP");

	if (setsockopt(sock, SOL_IP, IP_MULTICAST_IF, &mreq, sizeof(mreq)) < 0)
		error("setsockopt IP_MULTICAST_IF");

	opt = multittl;
	if (setsockopt(sock, SOL_IP, IP_MULTICAST_TTL, &opt, sizeof(opt)) < 0)
		error("setsockopt IP_MULTI_TTL");

	opt = 0;
	if (setsockopt(sock, SOL_IP, IP_MULTICAST_LOOP, &opt, sizeof(opt)) < 0)
		error("setsockopt IP_MULTI_LOOP");

	if (inet_ntop(AF_INET, &mreq.imr_multiaddr, addrtext, sizeof(addrtext))
	        == NULL)
		error("inet_ntop mreq.imr_multiaddr");
	if (inet_ntop(AF_INET, &mreq.imr_address, addrtext2, sizeof(addrtext2))
	        == NULL)
		error("inet_ntop mreq.imr_address");
	//syslog(LOG_INFO, "Joined multicast group %s on %s (interface %s)\n",
	//	       addrtext, addrtext2, mifacename);

	time0 = time(NULL);

	// Get Net Info, do here will speed up the response packet for the "NAV+"
	//unlink(_PATH_TMP_NETINFO);

//    sprintf(command, "killall net_util_getnet.pl >/dev/null 2>/dev/null"); system(command); //kill the last net_util_getnet.pl to prevent some error.
//    sprintf(command, _PATH_PERL_GETNETINFO" >/dev/null 2>/dev/null"); system(command); //call the perl before run fagent+
//	getnetinfo(netinfo, miface);
	
	while (1) {
		//crond_chk();//Minging.Tsai. 2014/5/1. Add a walk around to make sure the crond always on.
		struct timeval tv;
		fd_set fdset;
		int retcode;

		//sprintf(command, "killall net_util_getnet.pl >/dev/null 2>/dev/null"); system(command); //kill the last net_util_getnet.pl to prevent some error.
		//sprintf(command, _PATH_PERL_GETNETINFO" >/dev/null 2>/dev/null"); system(command); //call the perl before run fagent+
		getnetinfo(netinfo, miface);
		FD_ZERO(&fdset);
		FD_SET(sock, &fdset);
		tv.tv_sec = 5;
		tv.tv_usec = 0;
		// linux specifics: tv gets updated automatically
		while (((retcode = select(sock + 1, &fdset, NULL, NULL, &tv)) < 0)
		        && (errno == EINTR));
		if (retcode < 0)
			error("select");
		else if (!retcode) {
			//if (debug)
				//syslog(LOG_INFO, "timeout waiting for input");
		} else {
			if ((len = recvfrom(sock, &br, sizeof(br), 0,
			                    (struct sockaddr *) &foreignaddr, &foreignaddrlen)) < 0)
				error("recvfrom");

			inet_ntop(AF_INET, &foreignaddr.sin_addr,
			          addrtext, sizeof(addrtext));
			/*syslog(LOG_INFO, "From %s:%d \"%s\"\n", addrtext,
			       ntohs(foreignaddr.sin_port),
			       len >= sizeof(br) - sizeof(br.bootfile)
			       - sizeof(br.vendor) ? (char *)&br.servername :
			       "(BOOTP packet too small)");*/
			process_bootp_packet(&br, len, &bi);

// Print
//			fprintf(stdout, "IP = %d.%d.%d.%d\n",
//					br.yiaddr[0], br.yiaddr[1], br.yiaddr[2], br.yiaddr[3]);
//			fprintf(stdout, "HWADDR = %d %d %d %d %d %d\n",
//					br.hwaddr[0], br.hwaddr[1], br.hwaddr[2], br.hwaddr[3], br.hwaddr[4], br.hwaddr[5]);

			if (br.hwaddr[0] == 0 && br.hwaddr[1] == 0 && br.hwaddr[2] == 0 &&
			        br.hwaddr[3] == 0 && br.hwaddr[4] == 0 && br.hwaddr[5] == 0 ) {

				if ( br.yiaddr[0] == 0 && br.yiaddr[1] == 0 && br.yiaddr[2] == 0 && br.yiaddr[3] == 0 ) {
					//syslog (LOG_DEBUG, "%s", br.bootfile);
					strncpy( ident, br.bootfile, 4);

					ident[4] = '\0';
					if ( ! strcmp(ident,"NAV+") ) {
//						printf("Got NAV+ from %s\n", miface);
						sprintf(command, "echo \"receive nasfinder NAV+ `date -u`\">/tmp/fagent+"); system(command); //kill the last net_util_getnet.pl to prevent some error.
//						sprintf(command, _PATH_PERL_GETNETINFO" >/dev/null 2>/dev/null"); system(command); //call the perl before run fagent+
						//Minging.Tsai. 2013/10/25.
						//char recv_helios_sn[19];
						//strncpy( recv_helios_sn, br.bootfile + 4, 19);
						//recv_helios_sn[18] = '\0';
						//printf("recv_helios_sn=\"%s\"\n", recv_helios_sn);

						//char recv_helios_ip[INET_ADDRSTRLEN];
						//inet_ntop(AF_INET, &(foreignaddr.sin_addr), recv_helios_ip, INET_ADDRSTRLEN);
						//printf("recv_helios_ip=\"%s\"\n", recv_helios_ip);

						//char cmd[128];
						//memset(cmd, 0, 128);
						//sprintf(cmd, "/nasapp/perl/util/net_util_chkjoininfo.pl \"%s\" \"%s\" &", recv_helios_ip, recv_helios_sn);
						//system(cmd);

						memset(&bp.bootfile, 0, sizeof(bp.bootfile));
						
						//unlink(_PATH_TMP_NETINFO);//Minging.Tsai. 2013/8/13. For nasfinder can get lastest information.
						//sprintf(command, _PATH_PERL_GETNETINFO" >/dev/null 2>/dev/null");		system(command);
						//sleep(3);
						getnetinfo(netinfo, miface);
	
						strncpy((char *)&bp.bootfile, netinfo, sizeof(bp.bootfile));
						memset(&foreignaddr, 0, sizeof(foreignaddr));
						foreignaddr.sin_family = AF_INET;
						foreignaddrlen = sizeof(foreignaddr);

						if (!server) {
							foreignaddr.sin_addr = mreq.imr_multiaddr;
							foreignaddr.sin_port = htons(serverport);

							//printf("bp.bootfile=%s\n", (char *)&bp.bootfile);
							bp.secs = htons((u_int16_t)(time(NULL) - time0));
							int error_count = 0;
							while ((len = sendto(sock, &bp, sizeof(bp), 0, (struct sockaddr *) &foreignaddr, foreignaddrlen)) < 0) {
								//printf("sendto error?\n");
								sleep(2);
								if(error_count > 10) {
									break;
								}
								error_count++;
								perror("client sendto request");
								//error("client sendto request");	//error() will call exit() to terminate the program
							}
							//printf("len =%d\n",len);
							sprintf(command, "echo \"reply nasfinder len=%d, error_count=%d\">>/tmp/fagent+", len, error_count); system(command); //kill the last net_util_getnet.pl to prevent some error.

						}
						//fprintf(stdout, "Say Hello\n");
					}
				}
			}
			else if(br.hwaddr[0] == bp.hwaddr[0] && br.hwaddr[1] == bp.hwaddr[1] && br.hwaddr[2] == bp.hwaddr[2] &&
			        br.hwaddr[3] == bp.hwaddr[3] && br.hwaddr[4] == bp.hwaddr[4] && br.hwaddr[5] == bp.hwaddr[5] ) {
				
				//printf("Get something!!\n");
				
				//syslog (LOG_DEBUG, "%s", br.bootfile);

				strncpy( ident, br.bootfile, 4);
				ident[4] = '\0';
				strcpy(recvalue,br.bootfile+5);

				if ( ! strcmp(ident,"AUTH") ) {
					//syslog (LOG_DEBUG, "AUTH: %s %s", ident, recvalue);
					result = login(recvalue);
					//syslog (LOG_DEBUG, "AUTH: RESULT %d", result);

					if ( result == 0 ) {
						strncpy((char *)&bp.bootfile, "AUTH&OK&", sizeof(bp.bootfile));
					}
					else {
						strncpy((char *)&bp.bootfile, "AUTH&FAIL&", sizeof(bp.bootfile));
					}

					memset(&foreignaddr, 0, sizeof(foreignaddr));
					foreignaddr.sin_family = AF_INET;
					foreignaddrlen = sizeof(foreignaddr);

					if (!server) {
						foreignaddr.sin_addr = mreq.imr_multiaddr;
						foreignaddr.sin_port = htons(serverport);

						bp.secs = htons((u_int16_t)(time(NULL) - time0));
						if ((len = sendto(sock, &bp,
						                  sizeof(bp) - sizeof(bp.vendor) + vendorlen,
						                  0 , (struct sockaddr *) &foreignaddr, foreignaddrlen)) < 0)
							error("client sendto request");
					}
				}
				else if ( ! strcmp(ident,"SNET") ) {
					//printf("SNET!!\n");
					/* it will receive the same packet three times */
					//printf("Got SNET from %s\n", miface);
					if (strncmp(br.servername, servername, sizeof(br.servername))) {
						sprintf(command, _PATH_PERL_SETHOSTNAME" \"/tmp/null\" \"%s\" >/dev/null 2>/dev/null", br.servername+8/*promise&*/);
						system(command);
					}
					//sprintf( command, "/bin/echo \"%s\" > /tmp/fagent+", recvalue );
					sprintf(command, _PATH_SH_SETNET" \"%s\" >/dev/null 2>/dev/null", recvalue);
					system(command);
				}
				else {
					sprintf( command, "/bin/echo \"%s\" > /tmp/fagent+", br.bootfile );
					system(command);
				}
			}
			//if (!strncmp(br.servername, servername, sizeof(br.servername)))
			//	break;
		}
	}

	if (setsockopt(sock, SOL_IP, IP_DROP_MEMBERSHIP, &mreq, sizeof(mreq)) < 0)
		error("setsockopt IP_DROP_MEMBERSHIP");
	close(sock);

	exit(EXIT_SUCCESS);
}

