#  
#  Promise Technology, INC.
#  
#  Author : Steven Yang
#  Date   : 2005/05/24
#
#  Description
#  ====================================================================================
#  Makfile for MAPI 
#

CC					= gcc
CP					= cp
CFLAGS					+= -fPIC 
DFLAGS					= -DLINUX -D_REENTRANT -DDEBUG
INCLUDES 				= -I./
OBJS					= fagent.o auth.o crond_check.o 

all: fagent

fagent: $(OBJS)
	$(CC) -g $(OBJS) -lcrypt -o fagent+

.c.o:
	$(CC) -c $(CFLAGS) $(DFLAGS) $(INCLUDES) $<

clean:
	rm -f fagent+ *.o *.so *.bak core

