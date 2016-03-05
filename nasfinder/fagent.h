/*******************************************************************************
 * Filename    : fagent.h
 * Description : Finder agent header file
 *
 * Created on  : 06/10/04
 * CVS Version : $Id: fagent.h 2866 2011-03-02 12:10:27Z hungkai.hsueh $
 *
 * (C) Copyright Promise Technology Inc., 2004
 * All Rights Reserved
 ******************************************************************************/

#include <sys/types.h>

/* Code stolen from pump -- dhcp.c -- (C) RedHat, Inc */
/* See also RFC 1533 */
#define BOOTP_OPTION_NETMASK		1
#define BOOTP_OPTION_GATEWAY		3
#define BOOTP_OPTION_DNS		6
#define BOOTP_OPTION_HOSTNAME		12
#define BOOTP_OPTION_BOOTFILE		13
#define BOOTP_OPTION_DOMAIN		15
#define BOOTP_OPTION_BROADCAST		28
#define BOOTP_OPTION_NISDOMAIN		40

#define DHCP_OPTION_LOGSRVS		7
#define DHCP_OPTION_LPRSRVS		9
#define DHCP_OPTION_NTPSRVS		42
#define DHCP_OPTION_XFNTSRVS		48
#define DHCP_OPTION_XDMSRVS		49
#define DHCP_OPTION_REQADDR		50
#define DHCP_OPTION_LEASE		51
#define DHCP_OPTION_OVERLOAD		52
#define DHCP_OPTION_TYPE		53
#define DHCP_OPTION_SERVER		54
#define DHCP_OPTION_OPTIONREQ		55
#define DHCP_OPTION_MAXSIZE		57
#define DHCP_OPTION_T1			58
#define DHCP_OPTION_CLASS_IDENTIFIER	60
#define DHCP_OPTION_CLIENT_IDENTIFIER	61

#define BOOTP_CLIENT_PORT	68
#define BOOTP_SERVER_PORT	67

#define BOOTP_OPCODE_REQUEST	1
#define BOOTP_OPCODE_REPLY	2

#define NORESPONSE		-10
#define DHCP_TYPE_DISCOVER	1
#define DHCP_TYPE_OFFER		2
#define DHCP_TYPE_REQUEST	3
#define DHCP_TYPE_DECLINE	4
#define DHCP_TYPE_ACK		5
#define DHCP_TYPE_NAK		6
#define DHCP_TYPE_RELEASE	7
#define DHCP_TYPE_INFORM	8

#define DEFAULT_NUM_RETRIES	5
#define DEFAULT_TIMEOUT 	30

#define BOOTP_VENDOR_LENGTH	64
#define DHCP_VENDOR_LENGTH	1

typedef u_int8_t ipv4addr[4] __attribute__ ((packed));

typedef struct {
	u_int8_t opcode;
	u_int8_t hw;
	u_int8_t hwlength;
	u_int8_t hopcount;
	u_int32_t xid;
	u_int16_t secs;
	u_int16_t flags;
	ipv4addr ciaddr, yiaddr, server_ip, bootp_gw_ip;
	u_int8_t hwaddr[16];
	u_int8_t servername[64];
	//u_int8_t bootfile[1239];
	u_int8_t bootfile[1500];
	u_int8_t vendor[DHCP_VENDOR_LENGTH];
} __attribute__ ((packed)) bootp_packet;

#define MAX_DNS_SERVERS		3
#define MAX_LOG_SERVERS		3
#define MAX_LPR_SERVERS		3
#define MAX_NTP_SERVERS		3
#define MAX_XFS_SERVERS		3
#define MAX_XDM_SERVERS		3

#define PUMP_INTFINFO_HAS_IP		(1 << 0)
#define PUMP_INTFINFO_HAS_NETMASK	(1 << 1)
#define PUMP_INTFINFO_HAS_BROADCAST	(1 << 2)
#define PUMP_INTFINFO_HAS_NETWORK	(1 << 3)
#define PUMP_INTFINFO_HAS_DEVICE	(1 << 4)
#define PUMP_INTFINFO_HAS_BOOTSERVER	(1 << 5)
#define PUMP_INTFINFO_HAS_BOOTFILE	(1 << 6)
#define PUMP_INTFINFO_HAS_LEASE		(1 << 7)
#define PUMP_INTFINFO_HAS_REQLEASE	(1 << 8)
#define PUMP_INTFINFO_HAS_NEXTSERVER	(1 << 9)

#define PUMP_NETINFO_HAS_LOGSRVS	(1 << 15)
#define PUMP_NETINFO_HAS_LPRSRVS	(1 << 16)
#define PUMP_NETINFO_HAS_NTPSRVS	(1 << 17)
#define PUMP_NETINFO_HAS_XFNTSRVS	(1 << 18)
#define PUMP_NETINFO_HAS_XDMSRVS	(1 << 19)
#define PUMP_NETINFO_HAS_GATEWAY	(1 << 20)
#define PUMP_NETINFO_HAS_HOSTNAME	(1 << 21)
#define PUMP_NETINFO_HAS_DOMAIN		(1 << 22)
#define PUMP_NETINFO_HAS_DNS		(1 << 23)
#define PUMP_NETINFO_HAS_NISDOMAIN	(1 << 24)

#define PUMP_FLAG_NODAEMON	(1 << 0)
#define PUMP_FLAG_NOCONFIG	(1 << 1)
#define PUMP_FLAG_FORCEHNLOOKUP	(1 << 2)
#define PUMP_FLAG_WINCLIENTID	(1 << 3)

#define PUMP_SCRIPT_NEWLEASE	1
#define PUMP_SCRIPT_RENEWAL	2
#define PUMP_SCRIPT_DOWN	3

/* all of these in_addr things are in network byte order! */
struct pumpNetIntf {
	char device[10];
	int set;
	ipv4addr ip, netmask, broadcast, network;
	ipv4addr bootServer, nextServer;
	char * bootFile;
	time_t leaseExpiration, renewAt;
	int reqLease;		/* in seconds */
	char * hostname, * domain;		/* dynamically allocated */
	char * nisDomain;			/* dynamically allocated */
	ipv4addr gateway;
	ipv4addr logServers[MAX_LOG_SERVERS];
	ipv4addr lprServers[MAX_LPR_SERVERS];
	ipv4addr ntpServers[MAX_NTP_SERVERS];
	ipv4addr xfntServers[MAX_XFS_SERVERS];
	ipv4addr xdmServers[MAX_XDM_SERVERS];
	ipv4addr dnsServers[MAX_DNS_SERVERS];
	int numLog;
	int numLpr;
	int numNtp;
	int numXfs;
	int numXdm;
	int numDns;
	int flags;
};

// auth.c Added by Steven
int check_auth(char *user,char *passwd);

