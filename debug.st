+Encoder subclass: #DebugEncoder variables: #(lines parser oldLine oldRange)
+Method subclass: #DebugMethod variables: #(lines)
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
lines
	^ lines
!
!DebugEncoder
method: maxTemps class: c text: text | ret |
	ret <- DebugMethod name: name byteCodes: byteCodes
		literals: literals stackSize: maxStack
		temporarySize: maxTemps class: c text: text.
	ret debug: lines.
	^ ret
!
!DebugMethod
debug: l
	lines <- l
!
!DebugMethod
debug
	^ lines
!
!Class
debugMethod: n | meth |
	meth <- methods at: n asSymbol.
	^ (Parser new text: meth text instanceVars: self instanceVariables)
		parse: self with: DebugEncoder
!
