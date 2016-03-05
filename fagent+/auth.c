/*******************************************************************************
 * Filename    : auth.c
 * Description : The librarys about user authentication.
 *               
 * Created on  : 06/10/04
 * CVS Version : $Id: auth.c 2866 2011-03-02 12:10:27Z hungkai.hsueh $
 *
 * (C) Copyright Promise Technology Inc., 2004
 * All Rights Reserved
 ******************************************************************************/
 
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <pwd.h>
#include <crypt.h>

#include <sys/stat.h>
#include <fcntl.h>
#include <shadow.h>

#define SALT "$1$"

/*
 * pwd_to_spwd - create entries for new spwd structure
 *
 *  pwd_to_spwd() creates a new (struct spwd) containing the
 *  information in the pointed-to (struct passwd).
 */
#define DAY (24L*3600L)
#define WEEK (7*DAY)
#define SCALE DAY
struct spwd *pwd_to_spwd(const struct passwd *pw)
{
    static struct spwd sp;

    /*
     * Nice, easy parts first.  The name and passwd map directly
     * from the old password structure to the new one.
     */
    sp.sp_namp = pw->pw_name;
    sp.sp_pwdp = pw->pw_passwd;

    /*
     * Defaults used if there is no pw_age information.
     */
    sp.sp_min = 0;
    sp.sp_max = (10000L * DAY) / SCALE;
    sp.sp_lstchg = time((time_t *) 0) / SCALE;

    /*
     * These fields have no corresponding information in the password
     * file.  They are set to uninitialized values.
     */
    sp.sp_warn = -1;
    sp.sp_expire = -1;
    sp.sp_inact = -1;
    sp.sp_flag = -1;

    return &sp;
}

#define PWD_BUFFER_SIZE 256
struct spwd *getspnam(const char *name)
{
        static char buffer[PWD_BUFFER_SIZE];
        static struct spwd resultbuf;
        struct spwd *result;

        getspnam_r(name, &resultbuf, buffer, sizeof(buffer), &result);
        return result;
}

char *encrypt_passwd(const char *clear, const char *salt)
{
    static char cipher[128];
    char *cp;

    cp = (char *) crypt(clear, salt);
    /* if crypt (a nonstandard crypt) returns a string too large,
       truncate it so we don't overrun buffers and hope there is
       enough security in what's left */
    strncpy(cipher, cp, sizeof(cipher));
    return cipher;
}

char *get_passwd(const char *user)
{
    const struct spwd *sp;

 	  sp = getspnam(user);
 	  
 	  return sp->sp_pwdp; 	
}

int check_auth(char *user,char *passwd) {

 	 const struct passwd *pw;
 	 char *cipher;
	 char *crypt_passwd;

	 pw = getpwnam(user);
	 if (!pw) {
 	 	  return 1;
	 }

 	 crypt_passwd = get_passwd(user);
 	 
 	 if ( strcmp(crypt_passwd,"") == 0 ) {
 	 	  return 1;
 	 }
 	
   cipher = encrypt_passwd(passwd, crypt_passwd);
   
	 if ( strcmp(cipher, crypt_passwd) != 0 ) {
 	 	  return 1;
 	 }

   return 0;
}

int update_passwd(char *user, char *passwd)
{
	char filename[1024];
	char buf[1025];
	char buffer[80];
	char username[32];
	char *pw_rest;
	int has_shadow = 0;
	int mask;
	int continued;
	FILE *fp;
	FILE *out_fp;
	struct stat sb;
	struct flock lock;
	char *crypt_pw;

  crypt_pw = encrypt_passwd(passwd, SALT);
  
	if (access(SHADOW, F_OK) == 0) {
		has_shadow = 1;
	}
	if (has_shadow) {
		snprintf(filename, sizeof filename, "%s", SHADOW);
	} else {
		snprintf(filename, sizeof filename, "%s", SHADOW);
	}

	if (((fp = fopen(filename, "r+")) == 0) || (fstat(fileno(fp), &sb))) {
		/* return 0; */
		return 1;
	}

	/* Lock the password file before updating */
	lock.l_type = F_WRLCK;
	lock.l_whence = SEEK_SET;
	lock.l_start = 0;
	lock.l_len = 0;
	if (fcntl(fileno(fp), F_SETLK, &lock) < 0) {
		//fprintf(stderr, "%s: %s\n", filename, strerror(errno));
		return 1;
	}
	lock.l_type = F_UNLCK;

	snprintf(buf, sizeof buf, "%s+", filename);
	mask = umask(0777);
	out_fp = fopen(buf, "w");
	umask(mask);
	if ((!out_fp) || (fchmod(fileno(out_fp), sb.st_mode & 0777))
		|| (fchown(fileno(out_fp), sb.st_uid, sb.st_gid))) {
		fcntl(fileno(fp), F_SETLK, &lock);
		fclose(fp);
		fclose(out_fp);
		return 1;
	}

	continued = 0;
	snprintf(username, sizeof username, "%s:", user);
	rewind(fp);
	while (!feof(fp)) {
		fgets(buffer, sizeof buffer, fp);
		if (!continued) {		// Check to see if we're updating this line.
			if (strncmp(username, buffer, strlen(username)) == 0) {	// we have a match.
				pw_rest = strchr(buffer, ':');
				*pw_rest++ = '\0';
				pw_rest = strchr(pw_rest, ':');
				fprintf(out_fp, "%s:%s%s", buffer, crypt_pw, pw_rest);
			} else {
				fputs(buffer, out_fp);
			}
		} else {
			fputs(buffer, out_fp);
		}
		if (buffer[strlen(buffer) - 1] == '\n') {
			continued = 0;
		} else {
			continued = 1;
		}
		bzero(buffer, sizeof buffer);
	}

	if (fflush(out_fp) || fsync(fileno(out_fp)) || fclose(out_fp)) {
		unlink(buf);
		fcntl(fileno(fp), F_SETLK, &lock);
		fclose(fp);
		return 1;
	}
	if (rename(buf, filename) < 0) {
		fcntl(fileno(fp), F_SETLK, &lock);
		fclose(fp);
		return 1;
	} else {
		fcntl(fileno(fp), F_SETLK, &lock);
		fclose(fp);
		return 0;
	}
}

