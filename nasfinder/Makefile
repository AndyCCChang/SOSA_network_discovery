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
OBJS					= nasfinder.o

all: nasfinder

nasfinder: $(OBJS)
	$(CC) -g $(OBJS) -o nasfinder

.c.o:
	$(CC) -c $(CFLAGS) $(DFLAGS) $(INCLUDES) $<

clean:
	rm -f nasfinder *.o *.so *.bak core
	
