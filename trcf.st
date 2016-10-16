+File subclass: #TracedFile
!TracedFile
doRead
	| c |
	c <- super doRead.
	c notNil ifTrue: [ c asChar print. ].
	^ c.
!

