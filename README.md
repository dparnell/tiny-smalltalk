I found this code somewhere on the net and wanted to make sure I could find it again.

-------------------------------------------------------------------------------------



This is my work on Professor Timothy Budd's Smalltalk interpreter.
Over the years, he's implemented several, including one much smaller
than this, and one in Javascript.  This one's in C, and is a nice blend
of simplicity along with a "true" architectural approach to Smalltalk
and Object Oriented principles:

    (Quick OO test, if an object O has class C, what is the class of C?
     If you study the source here, you will find a deeper answer than
     you might expect, and one which is not understood by a surprising
     number of OO "masters".)

So hats off to Professor Budd.  This is offered as a derivative work
of his code, and is only available under the same terms.

Andy Valencia
http://vsta.org/contact/andy.html

====================================================================


                         Little Smalltalk, version 4.0
                       Timothy A. Budd, budd@cs.orst.edu
                            Oregon State University

   I first started developing Little Smalltalk back in 1984, and to tell
   the truth hadn't touched it for several years now. However, when I
   attended OOPSLA in Portland a few months ago, several things struck me:
     * Addison-Wesley was still selling my book ``A Little Smalltalk''
       (despite it being many years old now and very very dated), and
       people were still buying it (don't ask me why).
     * There was a heck of a lot of interest in Smalltalk on the vendor
       floor.
     * People kept asking me about Little Smalltalk.

   These things combined to make me think perhaps I should revisit Little
   Smalltalk. In my spare time since then I've been updating the system,
   and this is the result.

What Little Smalltalk is, and more importantly, what it isn't

   First and foremost, let me say at the beginning in as LOUD a voice as I
   can that Little Smalltalk is NOT a smalltalk-80 system. If you want a
   real Smalltalk system go buy one from ParcPlace, Digitalk, IBM, or
   whomever.

   Little Smalltalk is a sort of fun experiment in building a minimal
   smalltalk system. The source code for the interpreter is less than 1800
   lines of code. The image consists of less than 4000 objects. It runs in
   almost no memory. In short, it's small, it's reasonably fast, it's easy
   to understand, and easy to modify.

   As you might expect, in order to get Smalltalk to run in something this
   small, I've had to make lots of changes. Here are the most notable:
     * No graphics.
     * The user interface is a more conventional real-eval-print loop
       (like most Lisp systems), not a browser. (But it is all written in
       Smalltalk itself, so you can modify it if you wish).
     * Primitives and cascades are handled as they were in earlier Little
       Smalltalk systems, which is not how they are handed in
       Smalltalk-80.
     * The standard class hierarchy differs considerably from
       Smalltalk-80.
          + My basic collections are List, Tree, Dictionary, Array and
            String
          + The only numbers in the standard image are large and small
            integers (adding fractions and floats might be an interesting
            exercise, however).

Obtaining the system

   Anyway, if after this you still want to play with the system, here are
   the details. You can ftp from [1]ftp.cs.orst.edu. The file you are
   reading is found in [2]/users/b/budd/little on that system, and the
   file names I'm going to mention in a moment are found in that
   directory.

   Or, if you are using a WWW browser, you can set the option to copy
   sources to disk, and read the following files.
     * [3]distr.tar contains the entire distribution as a tar file.
       Alternatively, you can get it piece by piece.
     * The interpreter is contained in three files: [4]main.c (the main
       driver), [5]interp.c (the bytecode interpreter), [6]memory.c (the
       garbage collection system).
     * The standard image is found in the binary file named
       [7]LittleSmalltalkImage
     * Various test cases are found in a shar file named [8]Tests.

   To run the test cases use the fileIn: command (see ``documentation''
   below). I've only compiled the system on a sys-v based Unix system --
   but it uses nothing out of the ordinary so it may work on other
   systems. Let me know what problems you run into.

Documentation

   Documentation is, as usual, rather spare. In my spare time when I'm not
   hacking the system I am revising the Little Smalltalk book, and a few
   sample chapters are available in postscript form which you might
   find if you search hard enough.

Last words

   Have fun. Maybe this will be a real system some day. But I didn't think
   I should hold up distribution until that point.

Redistribution Rights and Standard Disclaimer

   Little Smalltalk can be freely and widely redistributed if not for
   profit and as long as the markings indicating origination are retained.

   The system is not supported (it's only a hobby for me), and is, of
   course, not warrantied as suitable for any use whatsoever.

