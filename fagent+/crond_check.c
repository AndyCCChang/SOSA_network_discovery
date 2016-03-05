//Minging.Tsai. 2014/5/1. Add in fagent to keep the crond alive. 
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
//#include <crond_check.h>

void crond_chk(void) {
	system("/etc/init.d/crond status >/tmp/crond_status");

	FILE *fp;
	char line[64];
	char flag[8] = "running";

	fp = fopen("/tmp/crond_status","r");
	while ( !feof(fp) ) {
		fgets(line, 64, fp);
		//printf("line=%s\n", line);
		break;
	}
	fclose(fp);
	unlink("/tmp/crond_status");
	char *loc; 
	loc= strstr(line, flag);
    if(loc == NULL) {
		//printf("Not running, start it.\n");
		system("/etc/init.d/crond start");
	}else {
		//printf("Found match at %d", loc - line);
	}

}
