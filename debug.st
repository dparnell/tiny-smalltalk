+Encoder subclass: #DebugEncoder variables: #(lines parser oldLine oldRange)
+Method subclass: #DebugMethod variables: #(lines)
+Object subclass: #Debug variables: #(ctx proc)
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
		'Compiling ' print. n printString print. '...' print.
		Char newline print.
		meth <- (Parser new text: meth text
			instanceVars: self instanceVariables)
			 parse: self with: DebugEncoder.
		meth notNil
			ifTrue: [
				methods at: s put: meth
			]
			ifFalse: [
				'Compilation failed.' print.
				Char newline print.
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
	ret <- proc doExecute: 1.
	(ret = 5) ifTrue: [ ^ true ].
	(ret = 3) ifTrue: [ 'Message not understood' print ].
	(ret = 2) ifTrue: [ 'Method returned' print ].
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
	meth <- ctx method.

	" Can't show it if this isn't a debuggable method "
	(meth isKindOf: DebugMethod) ifFalse: [
		^ nil
	].

	" Return source line pointer or nil "
	^ meth srcLine: ctx bytePointer.
!
!Debug
showLine | line meth |
	line <- self srcLine.
	line isNil
		ifTrue: [
			meth <- ctx method.
			'Method ' print.  meth name print.
			' of class ' print.  meth class print.
			': no source displayed.' print.
		]
		ifFalse: [
			" Show the text "
			(meth text at: line) print
		].
	Char newline print
!
=Debug
debug: class method: meth | ret ctx proc |
	ret <- super new.
	ctx <- Context new.
	ctx setup: meth withArguments: (Array new: 1).
	proc <- Process new.
	proc context: ctx.
	ret context: ctx proc: proc.
	ret run
!
!Debug
context: c proc: p
	ctx <- c.
	proc <- p
!
!Debug
run | prev did cmd srcl |
	prev <- ''.
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
			self runIt.
			did <- true
		].

		" Step a source line "
		((cmd = 'step') or: [cmd = 's']) ifTrue: [
			srcl <- self srcLine.
			[srcl = self srcLine] whileTrue: [
				(self runIt) ifFalse: [
					'Execution done at line ' print.
					srcl printString print.
					srcl = self srcLine
				]
			].
			did <- true
		].

		" Just let it run "
		((cmd = 'cont') or: [cmd = 'c']) ifTrue: [
			proc execute: ctx.
			^ nil
		].

		" Abandon the method "
		(cmd = 'quit') ifTrue: [
			^nil
		].

		" Stack backtrace "
		((cmd = 'where') or: [cmd = 'bt']) ifTrue: [
			ctx backtrace.
			did <- true
		].

		" Error "
		did ifFalse: [ 'Unknown command.' print ].

		" Add trailing newline "
		Char newline print.
	]
!
!DebugMethod
debug: l
	lines <- l
!
!DebugMethod
debug
	^ lines
!
!DebugMethod
srcLine: bp
	lines binaryDo: [:src :range |
		(range contains: bp) ifTrue: [
			^ src
		]
	].
	^nil
!
!Debug
test | sum |
	sum <- 0.
	1 to: 10 do: [:x| sum <- sum + x].
	^sum
!
