+Encoder subclass: #DebugEncoder variables: #(lines parser oldLine oldRange)
+Method subclass: #DebugMethod variables: #(lines textlines)
+Object subclass: #Debug variables: #(proc)
!DebugEncoder
parser: p
	lines <- Dictionary new.
	parser <- p.
	oldLine <- 0
!
!DebugEncoder
genCode: byte
	oldRange isNil
		ifTrue: [
			oldRange <- ((index + 1) to: (index + 1)).
			lines at: oldLine put: oldRange
		]
		ifFalse: [
			oldRange high: index + 1.
		].
	^ super genCode: byte
!
!DebugEncoder
lineNum: l
	(l ~= oldLine) ifTrue: [
		oldLine <- l.
		" We lazily insert the range, only at the point we
		  actually see some code generated for this source line."
		oldRange <- nil
	]
!
!DebugEncoder
method: maxTemps class: c text: text | ret |
	ret <- DebugMethod name: name byteCodes: byteCodes
		literals: literals stackSize: maxStack
		temporarySize: maxTemps class: c text: text.
	ret debug: lines.
	^ ret
!
!Class
debug: n | meth s |
	s <- n asSymbol.
	meth <- methods at: s.
	(meth isKindOf: DebugMethod) ifFalse: [
		'Compiling ' print. n printString print. '...' printNl.
		meth <- (Parser new text: meth text
			instanceVars: self instanceVariables)
			 parse: self with: DebugEncoder.
		meth notNil
			ifTrue: [
				methods at: s put: meth
			]
			ifFalse: [
				'Compilation failed.' printNl.
				^ nil
			]
	].
	Debug debug: self method: meth
!
!Debug
runIt | ret |
	" Execute for one instruction.  Return whether or not the return
	 was 'normal' (i.e., VM stopped due to single stepping, not
	 something else "
	ret <- proc doExecute: 2.
	(ret = 5) ifTrue: [ ^ true ].
	(ret = 4) ifTrue: [ 'Method returned' printNl ].
	(ret = 3) ifTrue: [ 'Message not understood' printNl ].
	(ret = 2) ifTrue: [ 'Error trap' printNl ].
	^ false
!
!Context
method
	^ method
!
!Context
bytePointer
	^ bytePointer
!
!Debug
srcLine | meth line |
	" Get source line corresponding to current byte pointer "
	meth <- proc context method.

	" Can't show it if this isn't a debuggable method "
	(meth isKindOf: DebugMethod) ifFalse: [
		'Not debuggable' printNl.
		^ nil
	].

	" Return source line pointer or nil "
	^ meth srcLine: proc context bytePointer.
!
!Debug
showLine | line meth |
	meth <- proc context method.
	line <- self srcLine.
	line isNil
		ifTrue: [
			'Method ' print.  meth name print.
			' of class ' print.  meth class print.
			': no source displayed.' printNl
		]
		ifFalse: [
			" Show the text "
			(meth textlines at: line) printNl
		]
!
=Debug
debug: class method: meth | ret ctx proc |
	ret <- super new.
	ctx <- Context new.
	ctx setup: meth withArguments: (Array new: 1).
	proc <- Process new.
	proc context: ctx.
	ret proc: proc.
	ret run
!
!Debug
proc: p
	proc <- p
!
!Debug
doStep | done srcl |
	done <- false.
	srcl <- self srcLine.
	[done not and: [srcl = self srcLine]]
	 whileTrue: [
		(self runIt) ifFalse: [
			'Execution done at line ' print.
			srcl printString printNl.
			done <- true
		]
	].
	^ done
!
!Debug
run | prev did cmd done |
	prev <- ''.
	done <- false.
	[true] whileTrue: [
		" Show where we are "
		self showLine.

		" Get command "
		'Debug> ' print.
		cmd <- String input.
		did <- false.
		(cmd isEmpty) ifTrue: [ cmd <- prev ].
		prev <- cmd.

		" Step a single VM instruction "
		(cmd = 'stepi') ifTrue: [
			done
			 ifTrue: [ 'Not runnable' printNl ]
			 ifFalse: [
				(self runIt) ifFalse: [
					done <- true
				]
			].
			did <- true
		].

		" Step a source line "
		((cmd = 'step') or: [cmd = 's']) ifTrue: [
			done
			 ifTrue: [ 'Not runnable' printNl ]
			 ifFalse: [
				done <- self doStep.
				did <- true
			 ]
		].

		" Just let it run "
		((cmd = 'cont') or: [cmd = 'c']) ifTrue: [
			proc execute.
			^ nil
		].

		" Abandon the method "
		(cmd = 'quit') ifTrue: [
			^nil
		].

		" Stack backtrace "
		((cmd = 'where') or: [cmd = 'bt']) ifTrue: [
			proc context backtrace.
			did <- true
		].

		" Error "
		did ifFalse: [ 'Unknown command.' printNl ].
	]
!
!DebugMethod
debug: l
	lines <- l.
	textlines <- text break: ((Char new: 10) asString)
!
!DebugMethod
debug
	^ lines
!
!DebugMethod
textlines
	^ textlines
!
!DebugMethod
srcLine: bp | bpx |
	" Array index version of bp... thanks, Smalltalk "
	bpx <- bp + 1.
	lines binaryDo: [:src :range |
		(range contains: bpx) ifTrue: [
			^ src
		]
	].
	'No match for ' print. bp printString printNl.
	^nil
!
!Debug
test | sum cnt |
	sum <- 0.
	cnt <- 1.
	[cnt < 3] whileTrue: [
		sum <- sum + cnt.
		cnt <- cnt + 1
	].
	sum <- sum + 20.
	sum printNl.
	^sum
!
