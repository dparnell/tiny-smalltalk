/*
	Little Smalltalk memory management
	Written by Tim Budd, budd@cs.orst.edu
	All rights reserved, no guarantees given whatsoever.
	May be freely redistributed if not for profit.

	Uses baker two-space garbage collection algorithm
*/

# include <stdio.h>
# include <stdlib.h>
# include "memory.h"
# include "globs.h"

extern int debugging;	/* true if we are debugging */

/*
	static memory space -- never recovered
*/
static struct object *staticBase, *staticTop, *staticPointer;

/*
	dynamic (managed) memory space
	recovered using garbage collection
*/

static struct object *spaceOne, *spaceTwo;
static int spaceSize;

struct object *memoryBase, *memoryPointer, *memoryTop;

static int inSpaceOne;
static struct object *oldBase, *oldTop;

/*
	roots for memory access
	used as bases for garbage collection algorithm
*/
struct object *rootStack[ROOTSTACKLIMIT];
int rootTop = 0;
#define STATICROOTLIMIT (200)
static struct object **staticRoots[STATICROOTLIMIT];
static int staticRootTop = 0;

/*
	test routine to see if a pointer is in dynamic memory
	area or not
*/

int
isDynamicMemory(struct object * x)
{
	return ((x >= spaceOne) && (x <= (spaceOne + spaceSize))) ||
		((x >= spaceTwo) && (x <= (spaceTwo + spaceSize)));
}

/*
	gcinit -- initialize the memory management system
*/
void
gcinit(int staticsz, int dynamicsz)
{
		/* allocate the memory areas */
	staticBase = (struct object *)
		malloc(staticsz * sizeof(struct object));
	spaceOne = (struct object *)
		malloc(dynamicsz * sizeof(struct object));
	spaceTwo = (struct object *)
		malloc(dynamicsz * sizeof(struct object));
	if ((staticBase == 0) || (spaceOne == 0) || (spaceTwo == 0))
		sysError("not enough memory for space allocations\n", 0);

	staticTop = staticBase + staticsz;
	staticPointer = staticTop;

	spaceSize = dynamicsz;
	memoryBase = spaceOne;
	memoryPointer = memoryBase + spaceSize;
	if (debugging) {
		printf("space one 0x%x, top 0x%x,"
				" space two 0x%x , top 0x%x\n",
			(uint)spaceOne, (uint)(spaceOne + spaceSize),
			(uint)spaceTwo, (uint)(spaceTwo + spaceSize));
	}
	inSpaceOne = 1;
}

/*
	gc_move is the heart of the garbage collection algorithm.
	It takes as argument a pointer to a value in the old space,
	and moves it, and everything it points to, into the new space
	The returned value is the address in the new space.
*/
struct mobject {
	int size;
	struct mobject * data [0];
};

static struct object *
gc_move(struct mobject * ptr)
{
	struct mobject *old_address = ptr, *previous_object = 0,
		*new_address = 0, *replacement  = 0;
	int sz;

	while (1) {

		/*
		 * part 1.  Walking down the tree
		 * keep stacking objects to be moved until we find
		 * one that we can handle
		 */
		for (;;) {
			/*
			 * SmallInt's are not proper memory pointers,
			 * so catch them first.  Their "object pointer"
			 * value can be used as-is in the new space.
			 */
			if (IS_SMALLINT(old_address)) {
				replacement = old_address;
				old_address = previous_object;
				break;

			/*
			 * If we find a pointer in the current space
			 * to the new space (other than indirections) then
			 * something is very wrong
			 */
			} else if ((old_address >=
			 (struct mobject *) memoryBase)
			 && (old_address <= (struct mobject *) memoryTop)) {
				sysError(
				 "GC invariant failure -- address in new space",
					(unsigned int)old_address);

			/* else see if not  in old space */
			} else if ((old_address < (struct mobject *) oldBase) ||
			 (old_address > (struct mobject *) oldTop)) {
				replacement = old_address;
				old_address = previous_object;
				break;

			/* else see if already forwarded */
			} else if (old_address->size & 01)  {
				if (old_address->size & 02) {
					replacement = old_address->data[0];
				} else {
					sz = old_address->size >> 2;
					replacement = old_address->data[sz];
				}
				old_address = previous_object;
				break;

			/* else see if binary object */
			} else if (old_address->size & 02) {
				int isz;

				isz = old_address->size >> 2;
				sz = (isz + BytesPerWord - 1)/BytesPerWord;
				memoryPointer -= (sz + 2);
				new_address = (struct mobject *) memoryPointer;
				new_address->size = (isz << 2) | 02;
				while (sz) {
					new_address->data[sz] =
						old_address->data[sz];
					sz--;
				}
				old_address->size |= 01;
				new_address->data[0] = previous_object;
				previous_object = old_address;
				old_address = old_address->data[0];
				previous_object->data[0] = new_address;
				/* now go chase down class pointer */

			/* must be non-binary object */
			} else  {
				sz = old_address->size >> 2;
				memoryPointer -= (sz + 2);
				new_address = (struct mobject *) memoryPointer;
				new_address->size = (sz << 2);
				old_address->size |= 01;
				new_address->data[sz] = previous_object;
				previous_object = old_address;
				old_address = old_address->data[sz];
				previous_object->data[sz] = new_address;
			}
		}

		/*
		 * part 2.  Fix up pointers,
		 * move back up tree as long as possible
		 * old_address points to an object in the old space,
		 * which in turns points to an object in the new space,
		 * which holds a pointer that is now to be replaced.
		 * the value in replacement is the new value
		 */
		for (;;) {
			/* backed out entirely */
			if (old_address == 0) {
				return (struct object *) replacement;
			}

			/* case 1, binary or last value */
			if ((old_address->size & 02) ||
			 ((old_address->size>>2) == 0)) {

				/* fix up class pointer */
				new_address = old_address->data[0];
				previous_object = new_address->data[0];
				new_address->data[0] = replacement;
				old_address->data[0] = new_address;
				replacement = new_address;
				old_address = previous_object;
			} else {
				sz = old_address->size >> 2;
				new_address = old_address->data[sz];
				previous_object = new_address->data[sz];
				new_address->data[sz] = replacement;
				sz--;

				/*
				 * quick cheat for recovering zero fields
				 */
				while (sz && (old_address->data[sz] == 0)) {
					sz--;
				}
				old_address->size = (sz << 2) | 01;
				new_address->data[sz] = previous_object;
				previous_object = old_address;
				old_address = old_address->data[sz];
				previous_object->data[sz] = new_address;
				break; /* go track down this value */
			}
		}
	}
}

/*
	gcollect -- garbage collection entry point
*/
extern int gccount;
struct object *
gcollect(int sz)
{
	int i;

	gccount++;
	/* first change spaces */
	if (inSpaceOne) {
		memoryBase = spaceTwo;
		inSpaceOne = 0;
		oldBase = spaceOne;
	} else {
		memoryBase = spaceOne;
		inSpaceOne = 1;
		oldBase = spaceTwo;
	}
	memoryPointer = memoryTop = memoryBase + spaceSize;
	bzero((char *) memoryBase, spaceSize * sizeof(struct object));
	oldTop = oldBase + spaceSize;

	/* then do the collection */
	for (i = 0; i < rootTop; i++) {
		rootStack[i] = gc_move((struct mobject *) rootStack[i]);
	}
	for (i = 0; i < staticRootTop; i++) {
		(* staticRoots[i]) =  gc_move((struct mobject *)
			* staticRoots[i]);
	}

	flushCache();

	/* then see if there is room for allocation */
	memoryPointer -= sz + 2;
	if (memoryPointer < memoryBase) {
		sysError("insufficient memory after garbage collection", sz);
	}
	memoryPointer->size =  sz << 2;
	return memoryPointer;
}

/*
	static allocation -- tries to allocate values in an area
	that will not be subject to garbage collection
*/

struct object *
staticAllocate(int sz)
{
	staticPointer -= sz + 2;
	if (staticPointer < staticBase) {
		sysError("insufficient static memory", 0);
	}
	staticPointer->size = sz << 2;
	return staticPointer;
}

struct object *
staticIAllocate(int sz)
{
	int trueSize;
	struct object * result;

	trueSize = (sz + BytesPerWord - 1) / BytesPerWord;
	result = staticAllocate(trueSize);
	result->size = (sz << 2) | 02;
	return result;
}

/*
	if definition is not in-lined, here  is what it should be
*/
# ifndef gcalloc
struct object *
gcalloc(int sz)
{
	struct object * result;

	memoryPointer -= sz + 2;
	if (memoryPointer < memoryBase) {
		return gcollect(sz);
	}
	memoryPointer->size =  sz << 2;
	return memoryPointer;
}
# endif

struct object *
gcialloc(int sz)
{
	int trueSize;
	struct object * result;

	trueSize = (sz + BytesPerWord - 1) / BytesPerWord;
	result = gcalloc(trueSize);
	result->size = (sz << 2) | 02;
	return result;
}

/*
	File in and file out of Smalltalk images
*/

static int indirtop = 0;
static struct object **indirArray;

static unsigned int
readWord(FILE * fp)
{
	int i;

	i = fgetc(fp);
	if (i == EOF) {
		sysError("unexpected end of file reading image file", 0);
	}
	if (i == 255) {
		return 255 + readWord(fp);
	} else {
		return i;
	}
}

static struct object *
objectRead(FILE * fp)
{
	int type, size, i;
	struct object *newObj = 0;
	struct byteObject *bnewObj;

	type = readWord(fp);

	switch (type) {
		case 0:	/* nil obj */
			sysError("read in a null object", (int)newObj);

		case 1:	/* ordinary object */
			size = readWord(fp);
			newObj = staticAllocate(size);
			indirArray[indirtop++] = newObj;
			newObj->class = objectRead(fp);
			for (i = 0; i < size; i++) {
				newObj->data[i] = objectRead(fp);
				}
			break;

		case 2: /* integer */
			size = readWord(fp);
			newObj = newInteger(size);
			break;

		case 3:	/* byte arrays */
			size = readWord(fp);
			newObj = staticIAllocate(size);
			indirArray[indirtop++] = newObj;
			bnewObj = (struct byteObject *) newObj;
			for (i = 0; i < size; i++) {
				type = readWord(fp);
				bnewObj->bytes[i] = type;
				}
			bnewObj->class = objectRead(fp);
			break;

		case 4:	/* previous object */
			size = readWord(fp);
			newObj = indirArray[size];
			break;

		case 5:	/* object 0 (nil object) */
			newObj = indirArray[0];
			break;
		}
	return newObj;
}


int
fileIn(FILE * fp)
{
	int i;

	/* use the currently unused space for the indir pointers */
	if (inSpaceOne) {
		indirArray = (struct object * *) spaceTwo;
	} else {
		indirArray = (struct object * *) spaceOne;
	}
	indirtop = 0;

	/* read in the method from the image file */
	nilObject = objectRead(fp);
	trueObject = objectRead(fp);
	falseObject = objectRead(fp);
	globalsObject = objectRead(fp);
	SmallIntClass = objectRead(fp);
	IntegerClass = objectRead(fp);
	ArrayClass = objectRead(fp);
	BlockClass = objectRead(fp);
	ContextClass = objectRead(fp);
	initialMethod = objectRead(fp);
	for (i = 0; i < 3; i++) {
		binaryMessages[i] = objectRead(fp);
	}

	/* clean up after ourselves */
	bzero((char *) indirArray, spaceSize * sizeof(struct object));
	return indirtop;
}

static void
writeWord(FILE * fp, int i)
{
	if (i < 0) {
		sysError("trying to write out negative value", i);
	}
	if (i >= 255) {
		fputc(255, fp);
		writeWord(fp, i - 255);
	} else {
		fputc(i, fp);
	}
}

static void
objectWrite(FILE *fp, struct object * obj)
{
	int i, size;

	if (obj == 0) {
		sysError("writing out a null object", (int)obj);
	}

	if (IS_SMALLINT(obj)) { /* SmallInt */
		writeWord(fp, 2);
		writeWord(fp, integerValue(obj));
		return;
	}

	/* see if already written */
	for (i = 0; i < indirtop; i++) {
		if (obj == indirArray[i]) {
			if (i == 0) {
				writeWord(fp, 5);
			} else {
				writeWord(fp, 4);
				writeWord(fp, i);
			}
			return;
		}
	}

	/* not written, do it now */
	indirArray[indirtop++] = obj;

	/* byte objects */
	if (obj->size & 02) {
		struct byteObject * bobj = (struct byteObject *) obj;
		size = obj->size >> 2;
		writeWord(fp, 3);
		writeWord(fp, size);
		for (i = 0; i < size; i++)
			writeWord(fp, bobj->bytes[i]);
		objectWrite(fp, obj->class);
		return;
	}

	/* ordinary objects */
	size = obj->size >> 2;
	writeWord(fp, 1);
	writeWord(fp, size);
	objectWrite(fp, obj->class);
	for (i = 0; i < size; i++) {
		objectWrite(fp, obj->data[i]);
	}
}

int
fileOut(FILE * fp)
{
	int i;

	/* use the currently unused space for the indir pointers */
	if (inSpaceOne) {
		indirArray = (struct object * *) spaceTwo;
	} else {
		indirArray = (struct object * *) spaceOne;
	}
	indirtop = 0;

	/* write out the roots of the image file */
	objectWrite(fp, nilObject);
	objectWrite(fp, trueObject);
	objectWrite(fp, falseObject);
	objectWrite(fp, globalsObject);
	objectWrite(fp, SmallIntClass);
	objectWrite(fp, ArrayClass);
	objectWrite(fp, BlockClass);
	objectWrite(fp, ContextClass);
	objectWrite(fp, initialMethod);
	for (i = 0; i < 3; i++) {
		objectWrite(fp, binaryMessages[i]);
	}
	printf("%d objects written in image\n", indirtop);

	/* clean up after ourselves */
	bzero((char *) indirArray, spaceSize * sizeof(struct object));
	return indirtop;
}

/*
 * addStaticRoot()
 *	Add another object root off a static object
 *
 * Static objects, in general, do not get garbage collected.  When
 * a static object is discovered adding a reference to a non-static
 * object, we link on the reference to our staticRoot table so we can
 * give it proper treatment during garbage collection.
 */
void
addStaticRoot(struct object **objp)
{
	int i;

	for (i = 0; i < staticRootTop; ++i) {
		if (objp == staticRoots[i]) {
			return;
		}
	}
	if (staticRootTop >= STATICROOTLIMIT) {
		sysError("addStaticRoot: too many static references",
			(unsigned int)objp);
	}
	staticRoots[staticRootTop++] = objp;
}
