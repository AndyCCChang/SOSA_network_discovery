#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <syslog.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <time.h>
#include <sys/types.h>

#include "fagent.h"


#define BUFLEN 1400
#define MSGKEY   "Promise&"
#define MAX_CLIENTS 256

int FillBuffer(char *buf, int opcode, char *netinfo_multi)
{
	unsigned char MAGIC_COOKIE[] = {99, 130, 83, 99};

	int n32;
	short n16;
	int length;
	buf[0] = 2;
	buf[1] = 1;
	buf[2] = 6;
	buf[3] = (unsigned char)255;

	n32 = 0x12345678;
	buf[7] = (unsigned char)n32;
	n32 >>= 8;
	buf[6] = (unsigned char)n32;
	n32 >>= 8;
	buf[5] = (unsigned char)n32;
	n32 >>= 8;
	buf[4] = (unsigned char)n32;
	n32 >>= 8;

	n16 = 0;
	buf[9] = (unsigned char)n16;
	n16 >>= 8;
	buf[8] = (unsigned char)n16;
	n16 >>= 8;


	n16 = 0;
	buf[11] = (unsigned char)n16;
	n16 >>= 8;
	buf[10] = (unsigned char)n16;
	n16 >>= 8;

	n32 = 0;

	buf[16] = buf[17] = buf[18] = buf[19] = 0;     //ip
	/*
	    buf[20] = 192;
	    buf[21] = 168;
	    buf[22] = 207;
	    buf[23] = 61;
	*/
	//24~27 bootp proxy (gateway) address

	memcpy(buf+44, MSGKEY, strlen(MSGKEY));
	if(opcode == 1 && netinfo_multi) {
		char *dmac = strstr(netinfo_multi, "&");
		if(dmac) {
			int i, j;
			char tmp[3] = {0};
			memcpy(buf+44+strlen(MSGKEY), netinfo_multi, dmac - netinfo_multi);
			dmac++;
			for(i=28, j=0; i < 34; i++, j++) {
				strncpy(tmp, dmac+(j*2), 2);
				buf[i] = strtol(tmp, NULL, 16);
			}

			char *msg = strstr(dmac, "&");
			if(msg) {
				msg++;
				memcpy(buf+113, msg, strlen(msg));
			}
		}
		buf[108] = 'S';
		buf[109] = 'N';
		buf[110] = 'E';
		buf[111] = 'T';
		buf[112] = '&';

		length = 1347/* 108 + sizeof(bootfile) */;
	} else {
		buf[108] = 'N';
		buf[109] = 'A';
		buf[110] = 'V';
		if(opcode != -1)
			buf[111] = '+';
		else
			buf[111] = 'I';

		length = 236;

		memcpy(buf+length, MAGIC_COOKIE, sizeof(MAGIC_COOKIE));

		length += sizeof(MAGIC_COOKIE);
	}

	buf[length++] = (unsigned char)0xFF;
	return length;
}

void usage() {
	fprintf(stderr,
	        "Usage: fagent [-i (INTERFACE_NAME | INTERFACE_ADDR)] [-g GROUP]\n"
	        "\t[-t TTL] [-T wait time] [-S PORT] [-C PORT] [-f output_file]\n");
	exit(EXIT_FAILURE);
}

int main(int argc, char **argv)
{
	FILE *fp;
	struct sockaddr_in myaddr;
	struct in_addr localInterface;
	struct sockaddr_in peeraddr, addr;
	int opt;
	int sockfd, sock, clientsockfd;
	bootp_packet bp, br;
	char recmsg[BUFLEN + 1];
	unsigned int socklen;
	int count;
	struct ip_mreqn mreq;
	int server_port = 3058;//49152;
	int client_port = 3059;//49153;
	char *logfile = "/tmp/nasfinder.log";
	char *multi_addr = "225.0.0.1";
	char *miface, *mifacename;
	char *netinfo_multi;
#define MAX_IFS 20
	struct ifreq ifaces[MAX_IFS];
	int mifaceind;
	u_int8_t mifacehwaddr[IFHWADDRLEN];
	struct in_addr mifaceaddr;
	int i;

	int waitTime = 1;
	int multittl = 31;
	int opcode = -1;
	miface = "eth0";
	mifacename = NULL;
	netinfo_multi = NULL;
	mifaceind = 0;
	memset(&mifaceaddr, 0, sizeof(mifaceaddr));
	mifaceaddr.s_addr = htonl(INADDR_ANY);
	memset(&mifacehwaddr, 0, sizeof(mifacehwaddr));

	while ((opt=getopt(argc,argv,"i:g:t:T:S:C:f:o:n:")) != EOF) {
		switch(opt) {
		case 'i':
			miface = optarg;
			break;

		case 'g':
			multi_addr = strdup(optarg);
			break;

		case 't':
			multittl = strtol(optarg, NULL, 0);
			if (errno)
				error("TTL must be a number");
			break;

		case 'T':
			waitTime = strtol(optarg, NULL, 0);
			if (errno)
				error("wait time must be a number");
			break;

		case 'S':
			server_port = strtol(optarg, NULL, 0);
			if (errno)
				error("SERVER_PORT must be a number");
			break;

		case 'C':
			client_port = strtol(optarg, NULL, 0);
			if (errno)
				error("CLIENT_PORT must be a number");
			break;

		case 'f':
			logfile = strdup(optarg);
			break;

		case 'o':
			opcode = strtol(optarg, NULL, 0);
			if (errno)
				error("opcode must be a number");
			break;

		case 'n':
			netinfo_multi = strdup(optarg);
			break;

		default:
			usage();
		}
	}

	sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);

	if (miface != NULL) {
		struct ifconf ifconfig;
		int i;

		ifconfig.ifc_len = sizeof(ifaces);
		ifconfig.ifc_req = (struct ifreq *)&ifaces;

		if (ioctl(sock, SIOCGIFCONF, &ifconfig) < 0)
			error("ioctl SIOCGIFCONF");

		for (i = 0; i < ifconfig.ifc_len / sizeof(struct ifreq); i++) {
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
		}
	}
	close(sock);
	if (mifacename == NULL)
		mifacename = "default";

#if 1
	/* setup client sock */
	clientsockfd = socket(PF_INET, SOCK_DGRAM, 0);
	if (clientsockfd < 0)
	{
		printf("Socket creating error\n");
		exit(1);
	}
	socklen = sizeof(struct sockaddr_in);

	memset(&myaddr, 0, socklen);
	myaddr.sin_family = PF_INET;
	myaddr.sin_addr.s_addr = inet_addr(multi_addr);//htonl(INADDR_ANY);
	myaddr.sin_port = htons(client_port);

	opt = 1;
	if (setsockopt(clientsockfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0)
		error("setsockopt SO_REUSEADDR");

	if (bind(clientsockfd, (struct sockaddr *) &myaddr,sizeof(struct sockaddr_in)) == -1)
	{
		printf("Bind error\n");
		close(clientsockfd);
		exit(0);
	}

	opt = multittl;
	if (setsockopt(clientsockfd, IPPROTO_IP, IP_MULTICAST_TTL, &opt, sizeof(opt)) < 0)
		error("setsockopt IP_MULTI_TTL");

	localInterface.s_addr = INADDR_ANY;
	if(setsockopt(clientsockfd, IPPROTO_IP, IP_MULTICAST_IF, (char *)&localInterface, sizeof(localInterface)) < 0)
	{
		perror("Setting local interface error");
		close(clientsockfd);
		exit(1);
	}

	// send multicast traffic to myself too
	opt = 1;
	if(setsockopt(clientsockfd, IPPROTO_IP, IP_MULTICAST_LOOP, &opt, sizeof(opt)) < 0)
		error("setsockopt IP_MULTICAST_LOOP");
	/* setup client sock end */
#endif

	sockfd = socket(AF_INET, SOCK_DGRAM, 0);
	if (sockfd < 0)
	{
		printf("Socket creating error\n");
		close(clientsockfd);
		exit(1);
	}
	bzero(&mreq, sizeof(struct ip_mreq));

	if (!inet_aton(multi_addr, &mreq.imr_multiaddr))
		error("inet_aton");

	mreq.imr_address = mifaceaddr;
	mreq.imr_ifindex = mifaceind;

	if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0)
		error("setsockopt SO_REUSEADDR");

	/* Add local to the multicast group */
	if (setsockopt(sockfd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq,sizeof(struct ip_mreq)) == -1)
	{
		perror("Setsockopt");
		close(clientsockfd);
		close(sockfd);
		exit(-1);
	}

	if (setsockopt(sockfd, IPPROTO_IP, IP_MULTICAST_IF, &mreq, sizeof(mreq)) < 0)
		error("setsockopt IP_MULTICAST_IF");

	opt = multittl;
	if (setsockopt(sockfd, IPPROTO_IP, IP_MULTICAST_TTL, &opt, sizeof(opt)) < 0)
		error("setsockopt IP_MULTI_TTL");

	socklen = sizeof(struct sockaddr_in);
	memset(&peeraddr, 0, socklen);
	peeraddr.sin_family = AF_INET;
	peeraddr.sin_port = htons(server_port);
	if (inet_pton(AF_INET, multi_addr, &peeraddr.sin_addr) <= 0)
	{
		printf("Wrong multicast address!\n");
		close(clientsockfd);
		close(sockfd);
		exit(0);
	}

	if (bind(sockfd, (struct sockaddr *) &peeraddr,sizeof(struct sockaddr_in)) == -1)
	{
		printf("Bind error\n");
		close(clientsockfd);
		close(sockfd);
		exit(0);
	}

	opt = fcntl(sockfd, F_GETFL);
	opt |= O_NONBLOCK;
	if (fcntl(sockfd, F_SETFL, opt) < 0) {
		printf("fcntl fail\n");
		close(clientsockfd);
		close(sockfd);
		exit(3);
	}

	memset(&br, 0, sizeof(br));
	int sendlen = FillBuffer((char*)&br, opcode, netinfo_multi);
	for (i=0; i<3; i++)
	{
		if (sendto(clientsockfd, &br, sendlen, 0,(struct sockaddr *) &myaddr,sizeof(struct sockaddr_in)) < 0)
		{
			printf("Sendto error!\n");
			close(clientsockfd);
			close(sockfd);
			exit(3);
		}
	}
	//sleep(1);
	if(opcode < 1)
	{
		u_int8_t hostname[MAX_CLIENTS][64]={0};
		u_int8_t hwaddr[MAX_CLIENTS][6]={0};
		u_int16_t host_num = 0;
		fp = fopen(logfile, "w");
		if (!fp) {
			close(clientsockfd);
			close(sockfd);
			exit(1);
		}
		int zero_counter = 0;
		//Minging.Tsai. 2013/8/8
		//In case nasfinder run too slow on Helios.

		printf("waitTime = %d\n", waitTime);
		for (i=0; i < 500; i++)//1000
		{
			bzero(&br, sizeof(br));
			count = recvfrom(sockfd, &br, sizeof(br), 0, (struct sockaddr *) &peeraddr, &socklen);
			if (count > 0)
			{
				printf("count = %d, i = %d\n", count, i);
				if(opcode == -1)
					fprintf(fp, "%s\n", br.bootfile);
				else
				{
					u_int8_t found = 0;
					u_int16_t i;
					/* Filter the same packet */
					for(i=0; i<host_num; i++)
					{
						if(!memcmp(hostname[i], br.servername+strlen(MSGKEY), 64) && !memcmp(hwaddr[i], br.hwaddr, 6)) {
//							printf("host_num = %d\n", host_num);
							found = 1;
							break;
						}
					}
					if(found == 0) {
						fprintf(fp, "%s&%02x%02x%02x%02x%02x%02x&%s\n", br.servername+strlen(MSGKEY), br.hwaddr[0], br.hwaddr[1], br.hwaddr[2], br.hwaddr[3], br.hwaddr[4], br.hwaddr[5], br.bootfile);
						memcpy(hostname[host_num], br.servername+strlen(MSGKEY), 64);
						memcpy(hwaddr[host_num], br.hwaddr, 6);
						host_num++;
					}
				}
			}
			else
				zero_counter++;

			//if(zero_counter >= )
//			printf("i = %d\n", i);

	struct timeval t_start,t_end;
    long cost_time = 0; 
	 //get start time
	 gettimeofday(&t_start, NULL);

	usleep(1000 * waitTime);//1000

	 gettimeofday(&t_end, NULL);

	 cost_time = t_end.tv_usec - t_start.tv_usec;
	 printf("Cost time: %ld us\n", cost_time);

		}

		fclose(fp);
		printf("Find log to '%s'\n", logfile);
	}

	/* Drop local from the multicast group */
	if (setsockopt(sockfd, IPPROTO_IP, IP_DROP_MEMBERSHIP, &mreq,sizeof(struct ip_mreq)) == -1)
	{
		perror("Setsockopt");
		close(clientsockfd);
		close(sockfd);
		exit(-1);
	}
	close(clientsockfd);
	close(sockfd);
}
