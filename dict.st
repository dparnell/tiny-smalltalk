+Set subclass: #Diction
+IdentitySet subclass: #IdentityDiction
!Diction
at: key ifAbsent: aBlock | pos assoc |
	pos <- self location: key.
	((pos isNil) or: [(assoc <- members at: pos) isNil]) ifTrue: [
		aBlock value
	].
	^ assoc value
!
!Diction
at: key put: value | assoc pos |
	" Create the Association "
	assoc <- Association key: key value: value.

	" Insert it using Set's method "
	self add: assoc.

	^ value
!
!Diction
binaryDo: aBlock
	members do: [:assoc|
		assoc notNil ifTrue: [ aBlock value: (assoc key)
			value: (assoc value) ]
	]
!
!Diction
keysDo: aBlock
	members do: [:assoc|
		assoc notNil ifTrue: [ aBlock value: (assoc key) ]
	]
!
!Diction
associationsDo: aBlock
	members do: [:assoc|
		assoc notNil ifTrue: [ aBlock value: assoc ]
	]
!
!Diction
basicDo: aBlock
	^ self associationsDo: aBlock
!
!Diction
keysAsArray | i ret |
	ret <- Array new: self size.
	i <- 1.
	members do: [:assoc| ret at: i put: assoc key. i <- i + 1 ].
	^ ret
!
!Diction
isEmpty
	members do: [:assoc| assoc notNil ifTrue: [ ^ false ]].
	^ true
!
!Diction
do: aBlock
	members do: [:assoc| assoc notNil ifTrue:
		[ aBlock value: (assoc value) ] ]
!
!Diction
removeKey: key ifAbsent: aBlock | assoc |
	assoc <- Association key: key value: nil.
	super remove: assoc ifAbsent: [ ^ aBlock value ].
	^ key
!
!Diction
removeKey: key
	^ self removeKey: key ifAbsent: [ self noElement ]
!
!Diction
remove: value ifAbsent: ignore
	self error: 'Can only remove by key'
!
