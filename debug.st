+Encoder subclass: #DebugEncoder variables: #(lines oldLine oldRange)
+Method subclass: #DebugMethod variables: #(lines textlines vars)
+Object subclass: #Debug variables: #(proc)
!DebugEncoder
name: n
	lines <- Dictionary new.
	oldLine <- 0.
	^ super name: n
!
!DebugEncoder
genCode: byte
	oldRange isNil ifTrue: [
		oldRange <- lines at: oldLine ifAbsent: [nil].
		oldRange isNil ifTrue: [
			oldRange <- Set new.
			lines at: oldLine put: oldRange
		]
	].
	oldRange add: (index + 1).
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
setDebug: sel | meth cl dict |
	" Chase up the superclass chain, trying to find our Method "
	cl <- self.
	[meth isNil] whileTrue: [
		dict <- cl methods.
		meth <- dict at: sel ifAbsent: [ cl <- cl superclass. nil].
		cl isNil ifTrue: [
			self error: ('Undefined method ' + sel printString +
				' for class ' + self printString)
		]
	].

	" If we haven't already fixed it up, build a DebugMethod version "
	(meth isKindOf: DebugMethod) ifFalse: [
		'Compiling ' print. sel printString print.
		' for class ' print. cl print.
		'...' printNl.
		meth <- (Parser new text: meth text
			instanceVars: self instanceVariables)
			 parse: self with: DebugEncoder.
		meth notNil
		 ifTrue: [
			cl methods at: sel put: meth.
			Method flushCache
		 ]
		 ifFalse: [
			'Compilation failed.' printNl.
		 ]
	].
	^ meth
!
!Debug
runIt: count | ret |
	" Execute for one instruction.  Return whether or not the return
	 was 'normal' (i.e., VM stopped due to single stepping, not
	 something else "
	ret <- proc doExecute: count+1.
	(ret = 5) ifTrue: [ ^ true ].
	(ret = 2) ifTrue: [ 'Error trap' printNl ].
	(ret = 3) ifTrue: [ 'Message not understood' printNl ].
	(ret = 4) ifTrue: [ 'Method returned' printNl ].
	(ret = 6) ifTrue: [ 'Breakpoint' printNl ].
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
!Context
stack
	^ stack
!
!Context
stackTop
	^ stackTop
!
!Context
temporaries
	^ temporaries
!
!Context
arguments
	^ arguments
!
!Method
forClass
	^ class
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
			' for class ' print.  meth forClass print.
			': no source displayed.' printNl
		]
		ifFalse: [
			" Show the text "
			(meth textlines at: line ifAbsent: ['']) printNl
		]
!
=Debug
run: line | meth ret ctx proc |
	meth <- (Parser new text: ('debugCmd ^' + line) instanceVars: #())
		 parse: Undefined with: DebugEncoder.
	meth notNil ifTrue: [
		ret <- super new.
		ctx <- Context new.
		ctx setup: meth withArguments: (Array new: 1).
		proc <- Process new.
		proc context: ctx.
		ret proc: proc.
		ret run
	]
!
!Debug
proc: p
	proc <- p
!
!Debug
atCall | ret meth ctx pc low high |
	" Get the next instruction "
	ctx <- proc context.
	meth <- ctx method.
	pc <- ctx bytePointer.
	high <- meth byteCodes at: (pc + 1).
	pc <- pc + 1.
	low <- high rem: 16.
	high <- high quo: 16.
	(high = 0) ifTrue: [
		high <- low.
		low <- meth byteCodes at: (pc + 1).
		pc <- pc + 1.
	].

	" Return nil if it isn't a SendMessage "
	(high = 9) ifFalse: [ ^ nil ].

	" Otherwise return the selector and return address "
	ret <- Array new: 2.
	ret at: 1 put: (meth literals at: (low + 1)).
	ret at: 2 put: pc.
	^ ret
!
!Debug
stepCall: sel | ctx stack sp args target meth |
	ctx <- proc context.
	stack <- ctx stack.
	sp <- ctx stackTop.
	args <- stack at: sp.
	target <- args at: 1.
	meth <- target class setDebug: sel.
	meth isNil ifTrue: [ ^ true ].
	(self runIt: 1) ifFalse: [
		'Execution done in ' print.
		meth name print.
		' of class ' print.
		target class printNl.
		^ true
	].
	^ false
!
!Debug
setBreak: pc | code ret |
	" Patch in a DoSpecial operation 12 (breakpoint) "
	" Return a record of how to undo this. "
	code <- proc context method byteCodes.
	ret <- Array new: 3.
	ret at: 1 put: code.
	ret at: 2 put: pc.
	ret at: 3 put: (code at: (pc + 1)).
	code at: (pc + 1) put: ((15*16) + 12).
	^ ret
!
!Debug
clearBreak: undo | code pc old |
	" Restore the previous code value "
	code <- undo at: 1.
	pc <- undo at: 2.
	old <- undo at: 3.
	code at: (pc + 1) put: old
!
!Debug
overCall: pc | ctx old res |
	" Set a breakpoint at the instruction beyond the SendMessage "
	ctx <- proc context.
	old <- self setBreak: pc.

	" Now let it run until it hits the breakpoint, and clear
	  the breakpoint. "
	res <- self runIt: -1.
	self clearBreak: old.
	res ifTrue: [
		" We shouldn't time out... "
		'Unexpected run completion' printNl.
		^ true
	].

	" Should be stopped at the expected location "
	((proc context = ctx) and:
			[ ctx bytePointer = pc ]) ifTrue: [
		^ false
	].

	" If not, we're done "
	'Execution aborted' printNl.
	^ true
!
!Debug
doStep: intoCalls | srcl ret |
	srcl <- self srcLine.
	[srcl = self srcLine] whileTrue: [
		" If dropping into a new method, deal with it "
		ret <- self atCall.
		ret notNil ifTrue: [
			" Stepping into the call "
			intoCalls ifTrue: [
				^ self stepCall: (ret at: 1)
			].

			" Stepping over call "
			(self overCall: (ret at: 2)) ifTrue: [
				^ true
			]
		] ifFalse: [
			" Otherwise run a single VM operation "
			(self runIt: 1) ifFalse: [
				'Execution done at line ' print.
				srcl printString printNl.
				^ true
			]
		]
	].
	^ false
!
!Debug
examine: arg | args var ctx meth |
	" Get the DebugMethod, which has symbolic information for variables "
	ctx <- proc context.
	meth <- ctx method.
	(meth isKindOf: DebugMethod) ifFalse: [
		'No debug information for ' print.
		meth name printNl.
		^ nil
	].

	" Walk each variable, printing its value "
	args <- arg break: ' '.
	2 to: args size do: [:x|
		var <- args at: x.
		var print. ': ' print.
		meth print: var in: ctx.
		Char newline print
	]
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
				(self runIt: 1) ifFalse: [
					done <- true
				]
			].
			did <- true
		].

		" Step a source line "
		((cmd = 'step') or: [cmd = 's']) ifTrue: [
			done
			 ifTrue: [ 'Not runnable' printNl ]
			 ifFalse: [ done <- self doStep: true ].
			did <- true
		].

		" Step a source line, stepping over message sends "
		((cmd = 'next') or: [cmd = 'n']) ifTrue: [
			done
			 ifTrue: [ 'Not runnable' printNl ]
			 ifFalse: [ done <- self doStep: false ].
			did <- true.
		].

		" Examine variables "
		(((cmd from: 1 to: 2) = 'p ') or: [
				(cmd from: 1 to: 6) = 'print ']) ifTrue: [
			self examine: cmd.
			did <- true
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
args: argNames inst: instNames temp: tempNames
	vars <- Array new: 3.
	vars at: 1 put: argNames.
	vars at: 2 put: instNames.
	vars at: 3 put: tempNames
!
!DebugMethod
srcLine: bp | bpx |
	" Array index version of bp... thanks, Smalltalk "
	bpx <- bp + 1.
	lines binaryDo: [:src :range |
		(range includes: bpx) ifTrue: [
			^ src
		]
	].
	'No match for ' print. bp printString printNl.
	^nil
!
!DebugMethod
print: var in: ctx | idx obj |
	" Name of an argument "
	idx <- (vars at: 1) indexOfVal: var.
	idx notNil ifTrue: [ (ctx arguments at: idx) printNl. ^ nil ].

	" Instance variable "
	idx <- (vars at: 2) indexOfVal: var.
	idx notNil ifTrue: [
		obj <- ctx arguments at: 1.
		(Object class in: obj at: idx) printNl.
		^ nil
	].

	" Temporary "
	idx <- (vars at: 3) indexOfVal: var.
	idx notNil ifTrue: [ (ctx temporaries at: idx) printNl. ^ nil ].

	" Couldn't find it... "
	'Unknown variable' printNl
!
