/*
 * globs.h
 *	Global defs for VM modules
 */
#ifndef GLOBS_H
#define GLOBS_H
#include <sys/types.h>
#include <stdio.h>

extern int fileIn(FILE * fp), fileOut(FILE * fp);
extern void sysError(char *, unsigned int), flushCache(void);

#endif /* GLOBS_H */
