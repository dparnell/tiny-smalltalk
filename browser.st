" browser.st
	Utility to interactively examine data structures
"
+Object subclass: #Browser variables: #(stack)

" on:
	Instantiate a browser on the named object
"
=Browser
on: obj
	self new on: obj
!

" showPos
	Display stack of objects we're inspecting
"
!Browser
showPos | cnt |
	' == stack -> ' print.
	cnt <- 0.
	stack reverseDo: [:obj|
		(cnt > 0) ifTrue: [ ' / ' print ].
		obj print.
		cnt <- cnt + 1
	].
	'' printNl
!

" ivars
	Dump instance variables of named object
"
!Browser
ivars: obj | iv |
	iv <- obj class instanceVariables.
	1 to: iv size do: [:idx|
		idx print. Char tab print.
		(iv at: idx) print. ': ' print.
		(Object in: obj at: idx) printNl
	]
!

" run:
	Compile and run Smalltalk expression on object
"
!Browser
run: args on: obj | t cl |
	" Assemble arguments into single String "
	args do: [:arg|
		t isNil ifTrue: [ t <- arg ]
		 ifFalse: [ t <- t + ' ' + arg ]
	].

	" Compile into xxBrowse Method for object's class "
	cl <- obj class.
	t <- 'xxBrowse' + String newline + String tab + '^ ' + t.
	(cl addMethod: t) notNil ifTrue: [
		" Compile OK, run and print result "
		obj xxBrowse printNl.
		" Now clean up (remove) browse method "
		cl removeMethod: #xxBrowse
	]
!

" scan:count:
	Internal step for choosing across a range of elements

 Returns a boolean for whether or not the scan should end.
"
!Browser
scan: elems count: count | c s |
	[ true ] whileTrue: [
		s <- String input.
		(s size = 0) ifFalse: [
			c <- s at: 1.
			(c = $q) ifTrue: [ ^ true ].
			(c = $ ) ifTrue: [ ^ false ].
			((c >= $0) and: [c < (48 + count) asChar]) ifTrue: [
				stack <- stack with:
					(elems at: (c value - 47)).
				^ true
			].
'Enter [ ] (space) to continue, [q]uit, or an index from 0 to ' print.
(47 + count) asChar printNl.
		]
	]
!

" scan:
	Scan across contents of object
"
!Browser
scan: obj | count elems |
	elems <- Array new: 10.
	count <- 0.
	obj do: [:o|
		((48 + count) asChar asString + ': ') print.
		count <- count + 1.
		elems at: count put: o.
		o printNl.
		(count >= 10) ifTrue: [
			(self scan: elems count: 10) ifTrue: [ ^ nil ].
			count <- 0
		]
	].
	(count > 0) ifTrue: [ self scan: elems count: count ]
!

" on:
	Main UI loop for browser
"
!Browser
on: top | cmd done obj args idx |
	stack <- Array with: top.
	[true] whileTrue: [
		" Show where we are and get next command "
		self showPos.

		" Get next command, explode into cmd/args "
		'Browse> ' print.
		cmd <- String input.
		(cmd isNil) ifTrue: [ ^ nil ].
		args <- cmd break: ' '.
		cmd <- args at: 1.
		args <- args from: 2.

		" Get top of stack in its own variable "
		obj <- stack at: (stack size).
		done <- false.

		" Index with at: "
		((cmd = 'i') or: [cmd = 'index']) ifTrue: [
			idx <- (args at: 1) asNumber.
			stack <- stack with: (obj at: idx).
			done <- true
		].

		" Show class "
		((cmd = 'c') or: [cmd = 'class']) ifTrue: [
			obj class printNl.
			done <- true
		].

		" Pop up a stack level "
		((cmd = 'u') or: [cmd = 'up']) ifTrue: [
			(stack size < 2) ifTrue: [
				'Stack is empty' printNl
			] ifFalse: [
				stack <- stack from: 1 to: (stack size - 1)
			].
			done <- true
		].

		" Raw index "
		(cmd = 'ri') ifTrue: [
			idx <- (args at: 1) asNumber.
			stack <- stack with: (Object in: obj at: idx).
			done <- true
		].

		" List instance variables "
		((cmd = 'iv') or: [cmd = 'ivars']) ifTrue: [
			self ivars: obj.
			done <- true
		].

		" Show size "
		((cmd = 'bs') or: [cmd = 'basicsize']) ifTrue: [
			obj basicSize printNl.
			done <- true
		].
		((cmd = 'sz') or: [cmd = 'size']) ifTrue: [
			obj size printNl.
			done <- true
		].

		" Print arbitrary expression "
		((cmd = 'p') or: [cmd = 'print']) ifTrue: [
			self run: args on: obj.
			done <- true
		].

		" Scan across contents "
		((cmd = 'z') or: [cmd = 'scan']) ifTrue: [
			(obj respondsTo: #do:) ifTrue: [
				self scan: obj
			] ifFalse: [
				'Not enumerable with do:' printNl.
			].
			done <- true
		].

		" All done "
		((cmd = 'q') or: [cmd = 'quit']) ifTrue: [
			^ nil
		].

		" Help "
		((cmd = '?') or: [cmd = 'help']) ifTrue: [
'Commands are:' printNl.
'i/index <number> - Index Array-type object' printNl.
'ri <number>      - Raw index into object''s instance vars' printNl.
'c/class          - Display class of current object' printNl.
'u/up             - Unnest to previous object' printNl.
'iv/ivars         - List instance vars' printNl.
'bs/basicsize     - Show basic size' printNl.
'sz/size          - Show size' printNl.
'p/print <expr>   - Print arbitrary expression' printNl.
'q/quit           - Return to system' printNl.
'z/scan           - Scan across elements of a Collection using do:' printNl.
'?/help           - This display' printNl.
			done <- true
		].

		" Unknown command? "
		done ifFalse: [ ('Unknown command: ' + cmd) printNl ]
	]
!
