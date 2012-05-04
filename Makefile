#
#	Makefile for Little Smalltalk system
#	written by Tim Budd, Oregon State University, budd@cs.orst.edu
#

CC=gcc
# CFLAGS=-g -Wall
# CFLAGS=-g -Wall -DDEBUG -DTRACE
CFLAGS=-O -g -Wall

LIBS=

st: main.o interp.o memory.o
	rm -f st
	$(CC) $(CFLAGS) -o st main.o interp.o memory.o $(LIBS)

distr.tar:
	tar cvf distr.tar ReadMe.html Makefile interp.h memory.h \
	main.c interp.c memory.c LittleSmalltalkImage Tests book.ps

#
#	Makefile Notes
#
#	main.c contains three defined constants that may need to be changed
#
#	memory.h defines the main memory allocation routine (gcalloc) as
#	a macro -- this can be commented out and a procedure call will
#	be used instead -- slower but safer during debugging
