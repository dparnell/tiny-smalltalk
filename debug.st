+Encoder subclass: #DebugEncoder variables: #(lines oldLine oldRange)
+Method subclass: #DebugMethod variables: #(lines textlines vars bpoints active)
+Object subclass: #Debug variables: #(proc bpoints)
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
	oldRange add: index.
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
	 was 'normal' (i.e., VM stopped due to debugger control, not
	 something else.  Spit out a message for a breakpoint. "
	ret <- proc doExecute: count+1.
	(ret = 5) ifTrue: [ ^ true ].
	(ret = 6) ifTrue: [ self onBreak. ^ true ].
	(ret = 2) ifTrue: [ 'Error trap' printNl ].
	(ret = 3) ifTrue: [ 'Message not understood' printNl ].
	(ret = 4) ifTrue: [ 'Method returned' printNl ].
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
	proc <- p.
	bpoints <- Array new: 0
!
!Debug
atCall | ret meth ctx pc low high |
	" Get the next instruction "
	ctx <- proc context.
	meth <- ctx method.
	pc <- ctx bytePointer.
	high <- meth byteCodes at: (pc + 1) ifAbsent: [ ^ nil ].
	pc <- pc + 1.
	low <- high rem: 16.
	high <- high quo: 16.
	(high = 0) ifTrue: [
		high <- low.
		low <- meth byteCodes at: (pc + 1) ifAbsent: [ ^ nil ].
		pc <- pc + 1
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
	" Set up to step into a new method "
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
onBreak | ctx meth rec |
	ctx <- proc context.
	ctx isNil ifTrue: [ ^ false ].
	meth <- ctx method.
	1 to: bpoints size do: [:idx|
		rec <- bpoints at: idx.
		((rec at: 1) = meth) ifTrue: [
			'Breakpoint ' print. idx print. ' hit in ' print.
			meth name printString print. '/' print.
			(rec at: 2) printNl.
			^ true
		]
	].
	^ false
!
!Debug
overCall: pc | ctx old res meth |
	" Set a breakpoint at the instruction beyond the SendMessage "
	ctx <- proc context.
	meth <- ctx method.
	meth setBreak: pc.

	" Now let it run until it hits the breakpoint, and clear
	  the breakpoint. "
	self breakActive: true. meth breakActive: true.
	res <- self runIt: -1.
	self breakActive: false.  meth clearBreak: pc.
	res ifTrue: [
		" Should be stopped at the expected location "
		((proc context = ctx) and:
				[ ctx bytePointer = pc ]) ifTrue: [
			^ false
		].

		" Or hit some other breakpoint "
		(self onBreak) ifTrue: [
			^ false
		].

		" Otherwise, what's going on? "
		'Unexpected run completion' printNl.
		^ true
	].

	" Some other error killed us "
	'Execution aborted' printNl.
	^ true
!
!Debug
doStep: intoCalls | srcl ret ctx |
	ctx <- proc context.
	srcl <- self srcLine.
	[(proc context = ctx) and:
			[srcl = self srcLine]] whileTrue: [
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
printReg: reg in: ctx
	(reg = '$pc') ifTrue: [
		ctx bytePointer print. ^ self
	].
	(reg = '$sp') ifTrue: [
		ctx stackTop print. ^ self
	].
	'Unknown register: ' print. reg print
!
!Debug
examine: args | ctx meth |
	" Get the DebugMethod, which has symbolic information for variables "
	ctx <- proc context.
	meth <- ctx method.
	(meth isKindOf: DebugMethod) ifFalse: [
		'No debug information for ' print.
		meth name printNl.
		^ nil
	].

	" Walk each variable, printing its value "
	args do: [:var|
		var print. ': ' print.
		((var at: 1) = $$)
		ifTrue: [
			self printReg: var in: ctx
		] ifFalse: [
			meth print: var in: ctx
		].
		Char newline print
	]
!
!Debug
setBreak: args | s cl clname meth methname i rec lineNum inClass |
	" Set the listed breakpoints "
	args do: [:arg|
		" Parse <class>:<method> "
		s <- arg break: '/'.
		(s size < 2) ifTrue: [
			'Format is <class>/<method>' printNl
		] ifFalse: [

		" Look up in instance methods unless it's =<class>,
		  in which case trim the '=' and look up in class
		  methods."
		clname <- s at: 1.
		((clname at: 1) = $=) ifTrue: [
			inClass <- true.
			clname <- clname from: 2 to: clname size
		] ifFalse: [
			inClass <- false
		].
		clname <- clname asSymbol.
		methname <- (s at: 2) asSymbol.

		" TBD: break at line # "
		(s size > 2) ifTrue: [
			lineNum <- (s at: 3) asNumber.
			lineNum isNil ifTrue: [
				'Bad line #, defaulting to 1' printNl.
				lineNum <- 1
			]
		] ifFalse: [
			lineNum <- 1
		].

		" Find class "
		cl <- Smalltalk at: clname ifAbsent: [
			('Unknown class: ' + clname) printNl.
			^ nil
		].

		" Convert to metaclass if needed "
		inClass ifTrue: [
			cl <- cl class
		].

		" Now get method, in its debuggable format "
		meth <- cl setDebug: methname.

		" If it's already set, don't do it again "
		rec <- Array with: meth with: lineNum.
		i <- bpoints indexOfVal: rec.
		i notNil ifTrue: [
			'Already set as breakpoint ' print.
			i printNl
		] ifFalse: [
			" Set & record the breakpoint "
			meth setBreak: 0.
			bpoints <- bpoints with: rec
		]
		]
	]
!
!Debug
clearBreak: args | arg n rec meth lineNum |
	arg <- args at: 1 ifAbsent: ['Missing argument' printNl. ^ nil].
	n <- arg asNumber.
	n isNil ifTrue: [
		('Invalid argument: ' + arg) printNl
	] ifFalse: [
		((n < 1) or: [n > bpoints size]) ifTrue: [
			('No such breakpoint: ' + arg) printNl
		] ifFalse: [
			rec <- bpoints at: n.
			meth <- rec at: 1.
			lineNum <- rec at: 2.
			meth clearBreak: 0.
			bpoints <- bpoints removeIndex: n.
			n print. ': deleted' printNl
		]
	]
!
!Debug
listBreak | rec meth lineNum |
	'Breakpoints:' printNl.
	1 to: bpoints size do: [:x|
		x print. ': ' print.
		rec <- bpoints at: x.
		meth <- rec at: 1.
		lineNum <- rec at: 2.
		meth name printString print. '/' print.
		lineNum printNl
	]
!
!Debug
breakActive: flag | meths |
	meths <- Set new.
	bpoints do: [:rec|
		meths add: (rec at: 1)
	].
	meths do: [:meth| meth breakActive: flag]
!
!Debug
run | prev did cmd done line |
	prev <- ''.
	done <- false.
	[true] whileTrue: [
		" Show where we are "
		self showLine.

		" Get command "
		'Debug> ' print.
		line <- String input.

		" Re-insert previous command if empty line "
		(line isEmpty) ifTrue: [ line <- prev ].
		prev <- line.

		" Parse into words "
		line <- line break: ' '.

		" Command is first, arguments follow "
		cmd <- line at: 1.
		line <- line from: 2 to: line size.

		" Set flag to indicate command hasn't matched yet "
		did <- false.

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
		((cmd = 'p') or: [cmd = 'print']) ifTrue: [
			self examine: line.
			did <- true
		].

		" Set a breakpoint "
		((cmd = 'b') or: [cmd = 'break']) ifTrue: [
			self setBreak: line.
			did <- true
		].

		" Clear breakpoint(s) "
		((cmd = 'd') or: [cmd = 'delete']) ifTrue: [
			self clearBreak: line.
			did <- true
		].

		" List breakpoints "
		((cmd = 'lb') or: [cmd = 'listbreaks']) ifTrue: [
			self listBreak.
			did <- true
		].

		" Just let it run "
		((cmd = 'cont') or: [cmd = 'c']) ifTrue: [
			" Step forward once, even over a breakpoint "
			done <- (self runIt: 1) not.

			" Now run until completion or next break "
			done ifFalse: [
				" Activate, run, and deactivate "
				self breakActive: true.
				done <- (self runIt: -1) not.
				self breakActive: false.

				" Display a message if hit a breakpoint "
				done ifFalse: [ self onBreak ].
			].

			did <- true
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
!String
asLines | c ret slot idx base top nl |
	" Size the array of lines which will result "
	nl <- Char newline.
	ret <- Array new: (self occurencesOf: nl) + 1.

	" Walk the elements, assembling lines "
	slot <- base <- idx <- 1.
	top <- self size.
	[idx < top] whileTrue: [
		c <- self at: idx.
		(c = nl) ifTrue: [
			ret at: slot put: (self from: base to: idx - 1).
			slot <- slot + 1.
			base <- idx + 1
		].
		idx <- idx + 1
	].
	(idx > top) ifTrue: [ idx <- top ].
	(idx > base) ifTrue: [
		ret at: slot put: (self from: base to: idx)
	].
	^ ret
!
!DebugMethod
debug: l
	lines <- l.
	textlines <- text asLines.
	bpoints <- Dictionary new.
	active <- false
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
srcLine: bp
	lines binaryDo: [:src :range |
		(range includes: bp) ifTrue: [
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
	idx notNil ifTrue: [ (ctx arguments at: idx) print. ^ nil ].

	" Instance variable "
	idx <- (vars at: 2) indexOfVal: var.
	idx notNil ifTrue: [
		obj <- ctx arguments at: 1.
		(Object class in: obj at: idx) print.
		^ nil
	].

	" Temporary "
	idx <- (vars at: 3) indexOfVal: var.
	idx notNil ifTrue: [ (ctx temporaries at: idx) print. ^ nil ].

	" Couldn't find it... "
	'Unknown variable' print
!
!DebugMethod
setBreak: bp | old |
	" If already set, ignore "
	(bpoints includes: bp) ifTrue: [ ^ self ].

	" Record current opcode at code location "
	old <- byteCodes at: (bp + 1).

	" Update the code location if it's already active "
	active ifTrue: [
		self patchBreak: bp active: true
	].

	" Record this breakpoint "
	bpoints at: bp put: old
!
!DebugMethod
clearBreak: bp
	" If not set, ignore "
	(bpoints includes: bp) ifFalse: [ ^ self ].

	" Restore code contents "
	self patchBreak: bp active: false.

	" Remove record of this breakpoint "
	bpoints removeKey: bp
!
!DebugMethod
clearAll
	bpoints keysDo: [:k|
		self clearBreak: k
	]
!
!DebugMethod
breakpoints
	^ bpoints keysAsArray
!
!DebugMethod
patchBreak: bp active: flag
	flag ifTrue: [
		" Patch in a DoSpecial operation 12 (breakpoint) "
		byteCodes at: (bp + 1) put: ((15*16) + 12)
	] ifFalse: [
		" Restore old code at this location "
		byteCodes at: (bp + 1) put: (bpoints at: bp)
	]
!
!DebugMethod
breakActive: flag
	" Skip all this if we aren't changing settings "
	(active = flag) ifTrue: [ ^ self ].

	" For each location with a breakpoint, update it "
	bpoints keysDo: [:bp|
		self patchBreak: bp active: flag
	].
	active <- flag
!
