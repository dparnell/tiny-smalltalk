/*
	Little Smalltalk main program, unix version
	Written by Tim Budd, budd@cs.orst.edu
	All rights reserved, no guarantees given whatsoever.
	May be freely redistributed if not for profit.

	starting point, primitive handler for unix
	version of the little smalltalk system
*/
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <limits.h>
#if defined(VSTA) && defined(PROFILE)
# include <mcount.h>
#endif
#include "globs.h"

/*
	the following defaults must be set

*/
# define DefaultImageFile "ImageBuilder/image"
# define DefaultStaticSize 40000
# define DefaultDynamicSize 40000
# define DefaultTmpdir "/tmp"

/*
--------------------
*/

# include "memory.h"
# include "interp.h"
# include <stdio.h>

/* # define COUNTTEMPS */

unsigned int debugging = 0, cacheHit = 0, cacheMiss = 0, gccount = 0;
static char *tmpdir = DefaultTmpdir;

void
sysError(char * a, unsigned int b)
{
	fprintf(stderr,"unrecoverable system error: %s 0x%x\n", a, b);
	exit(1);
}

void backTrace(struct object * aContext)
{
	printf("back trace\n");
	while (aContext && (aContext != nilObject)) {
		struct object * arguments; int i;
		printf("message %s ", 
			bytePtr(aContext->data[methodInContext]
				->data[nameInMethod]));
		arguments = aContext->data[argumentsInContext];
		if (arguments && (arguments != nilObject)) {
			printf("(");
			for (i = 0; i < (arguments->size >> 2); i++)
				printf("%s%s", 
				((i == 0) ? "" : ", "),
				bytePtr(arguments->data[i]->class->
					data[nameInClass]));
			printf(")");
			}
		printf("\n");
		aContext = aContext->data[previousContextInContext];
		}
}

# ifdef COUNTTEMPS
FILE * tempFile;
# endif

int
main(int argc, char ** argv)
{
	struct object *aProcess, *aContext, *o;
	int size, i, staticSize, dynamicSize;
	FILE *fp;
	char imageFileName[120], *p;

#if defined(VSTA) && defined(DEBUG)
	notify_handler(NULL);
#endif
	strcpy(imageFileName, DefaultImageFile);
	staticSize = DefaultStaticSize;
	dynamicSize = DefaultDynamicSize;

	/*
	 * See if our environment tells us what TMPDIR to use
	 */
	p = getenv("TMPDIR");
	if (p) {
		tmpdir = strdup(p);
	}

	/* first parse arguments */
	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-v") == 0) {
			printf("Little Smalltalk, version 4.01\n");
			}
		else if (strcmp(argv[i], "-s") == 0) {
			staticSize = atoi(argv[++i]);
		} else if (strcmp(argv[i], "-d") == 0) {
			dynamicSize = atoi(argv[++i]);
		} else if (strcmp(argv[i], "-g") == 0) {
			debugging = 1;
		} else {
			strcpy(imageFileName, argv[i]);
			}
		}

# ifdef COUNTTEMPS
	tempFile = fopen("/usr/tmp/counts", "w");
# endif

	gcinit(staticSize, dynamicSize);

	/* read in the method from the image file */
	fp = fopen(imageFileName, "r");
	if (! fp) {
		fprintf(stderr,"cannot open image file: %s\n", imageFileName);
		exit(1);
		}

	printf("%d objects in image\n", fileIn(fp));
	fclose(fp);

	/* build a context around it */

	aProcess = staticAllocate(3);
		/* context should be dynamic */
	aContext = gcalloc(contextSize);
	aContext->class = ContextClass;


	aProcess->data[contextInProcess] = aContext;
	size = integerValue(initialMethod->data[stackSizeInMethod]);
	aContext->data[stackInContext] = staticAllocate(size);
	aContext->data[argumentsInContext] = nilObject;

	aContext->data[temporariesInContext] = staticAllocate(19);
	aContext->data[bytePointerInContext] = newInteger(0);
	aContext->data[stackTopInContext] = newInteger(0);
	aContext->data[previousContextInContext] = nilObject;
	aContext->data[methodInContext] = initialMethod;

	/* now go do it */
	rootStack[rootTop++] = aProcess;

#if defined(VSTA) && defined(PROFILE)
	take_samples(1);
#endif
	switch(execute(aProcess, 0)) {
		case 2: printf("User defined return\n"); break;

		case 3: printf("can't find method in call\n"); 
			aProcess = rootStack[--rootTop];
			o = aProcess->data[resultInProcess];
			printf("Unknown method: %s\n", bytePtr(o));
			aContext = aProcess->data[contextInProcess];
			backTrace(aContext);
			break;

		case 4: printf("\nnormal return\n"); break;

		case 5: printf("time out\n"); break;

		default: printf("unknown return code\n"); break;
	}
#if defined(VSTA) && defined(PROFILE)
	dump_samples();
#endif
	printf("cache hit %u miss %u", cacheHit, cacheMiss);
#define SCALE (1000)
	while ((cacheHit > INT_MAX/SCALE) || (cacheMiss > INT_MAX/SCALE)) {
		cacheHit /= 10;
		cacheMiss /= 10;
	}
	i = (SCALE * cacheHit) / (cacheHit + cacheMiss);
	printf(" ratio %u.%u%%\n", i / 10, i % 10);
	printf("%u garbage collections\n", gccount);
	return(0);
}

/*
	primitive handler
	(note that many primitives are handled in the interpreter)
*/

# define FILEMAX 10
FILE * filePointers[FILEMAX];
int fileTop = 0;

void
getUnixString(char * to, int size, struct object * from)
{
	int i;
	int fsize = from->size >> 2;
	struct byteObject * bobj = (struct byteObject *) from;

	if (fsize > size) sysError("error converting text into unix string",
		fsize);
	for (i = 0; i < fsize; i++)
		to[i] = bobj->bytes[i];
	to[i] = '\0';	/* put null terminator at end */
}

struct object *
primitive(int primitiveNumber, struct object * args)
{
	struct object *returnedValue = nilObject;
	int i, j;
	FILE * fp;
	char * p;
	struct byteObject * stringReturn;
	char nameBuffer[80], modeBuffer[80];

	switch(primitiveNumber) {
	case 100: 	/* open a file */
		getUnixString(nameBuffer, 80, args->data[0]);
		getUnixString(modeBuffer, 10, args->data[1]);
		fp = fopen(nameBuffer, modeBuffer);
		if (fp != NULL) {
			if (fileTop + 1 >= FILEMAX) {
				sysError("too many open files", 0);
			}
			returnedValue = newInteger(fileTop);
			filePointers[fileTop++] = fp;
		}
		break;

	case 101:	/* read a single character from a file */
		if (!IS_SMALLINT(args->data[0])) {
			break;
		}
		i = integerValue(args->data[0]);
		if ((i < 0) || (i >= FILEMAX)) {
			break;
		}
		i = fgetc(filePointers[i]);
		if (i != EOF) {
			returnedValue = newInteger(i);
		}
		break;

	case 102:	/* write a single character to a file */
		if (!IS_SMALLINT(args->data[0])
				|| !IS_SMALLINT(args->data[1])) {
			break;
		}
		i = integerValue(args->data[0]);
		if ((i < 0) || (i >= FILEMAX)) {
			break;
		}
		fputc(integerValue(args->data[1]), filePointers[i]);
		break;

	case 103:	/* close file */
		if (!IS_SMALLINT(args->data[0])) {
			break;
		}
		i = integerValue(args->data[0]);
		if ((i < 0) || (i >= FILEMAX)) {
			break;
		}
		fclose(filePointers[i]);
		if (i+1 == fileTop) {
			fileTop--;
		}
		break;

	case 104:	/* file out image */
		i = integerValue(args->data[0]);
		fileOut(filePointers[i]);
		break;

	case 105:	/* edit a string */
			/* first get the name of a temp file */
		sprintf(nameBuffer, "%s/lsteditXXXXXX", tmpdir);
		mktemp(nameBuffer);
			/* copy string to file */
		fp = fopen(nameBuffer, "w");
		if (fp == NULL) 
			sysError("cannot open temp edit file", 0);
		j = args->data[0]->size >> 2;
		p = ((struct byteObject *) args->data[0])->bytes;
		for (i = 0; i < j; i++)
			fputc(*p++, fp);
		fputc('\n', fp);
		fclose(fp);
			/* edit string */
		strcpy(modeBuffer,"vi ");
		strcat(modeBuffer,nameBuffer);
		system(modeBuffer);
			/* copy back to new string */
		fp = fopen(nameBuffer, "r");
		if (fp == NULL) 
			sysError("cannot open temp edit file", 0);
			/* get length of file */
		fseek(fp, 0, 2);
		j = (int) ftell(fp);
		returnedValue = 
			(struct object *) stringReturn = gcialloc(j);
		returnedValue->class = args->data[0]->class;
			/* reset to beginning, and read values */
		fseek(fp, 0, 0);
		for (i = 0; i < j; i++)
			stringReturn->bytes[i] = fgetc(fp);
			/* now clean up files */
		fclose(fp);
		unlink(nameBuffer);
		break;

	default:
		sysError("unknown primitive", primitiveNumber);
	}
	return returnedValue;
}
