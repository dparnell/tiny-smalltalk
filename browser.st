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
	stack do: [:obj|
		(cnt > 0) ifTrue: [ ' / ' print ].
		obj print.
		cnt <- cnt + 1
	].
	'' printNl
!

" browse
	Initiate browsing on self
"
!Object
browse
	Browser on: self
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

" on:
	Main UI loop for browser
"
!Browser
on: top | cmd done last obj args idx |
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
			last <- stack at: (stack size).
			idx <- (args at: 1) asNumber.
			last <- last at: idx.
			last printNl.
			done <- true
		].

		" Nest to last displayed object "
		((cmd = 'n') or: [cmd = 'nest']) ifTrue: [
			stack <- stack with: last.
			done <- true
		].

		" Show class "
		((cmd = 'c') or: [cmd = 'class']) ifTrue: [
			obj class printNl.
			done <- true
		].

		" Pop up a stack level "
		((cmd = 'u') or: [cmd = 'up']) ifTrue: [
			stack <- stack from: 1 to: (stack size - 1).
			done <- true
		].

		" Raw index "
		(cmd = 'ri') ifTrue: [
			idx <- (args at: 1) asNumber.
			last <- Object in: obj at: idx.
			last printNl.
			done <- true
		].

		" List instance variables "
		((cmd = 'iv') or: [cmd = 'ivars']) ifTrue: [
			self ivars: obj.
			done <- true
		].

		" All done "
		((cmd = 'q') or: [cmd = 'quit']) ifTrue: [
			^ nil
		].

		" Unknown command? "
		done ifFalse: [ ('Unknown command: ' + cmd) printNl ]
	]
!
