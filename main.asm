b start

@i "header.asm"

@i "sprites.asm"
@i "background_tiles.asm"


playerBPressed:
; In Reg
; --
;
; Out Reg
; --
stmfd r13!,{r0}

ldrb r0,[r11,$2] ; player grounded flag
cmp r0,#1 ; check if player is grounded
bne skipPlayerJump

mvneq r0,#12
streqb r0,[r11,$1] ; y-vel
skipPlayerJump:

ldmfd r13!,{r0}
bx r14


handlePlayerSideCollision:
; In Reg
; r0: x pixel offset
; r3: horiz scroll amount
; r4: movement amount
;
; Out Reg
; r3: horiz scroll amount
stmfd r13!,{r0-r2,r5,r14}

mov r1,#31 ; y pixel offset: = h (31 pixels for player sprite height (pixels 0-31))
ldrh r2,[r7] ; y-pos (in OBJ 0 attrib 0)
and r2,r2,$FF ; mask only y-pos

bl getTileNearPlayerWithOffset

add r5,r8,$800 ; tilemap block offset
ldrh r0,[r5,r0]! ; tile directly next to player feet
cmp r0,$1 ; check if tile is floor tile
beq skipMovePlayerSide
sub r5,r5,$40 ; tile directly above
ldrh r0,[r5] ; "
cmp r0,$1 ;"
beq skipMovePlayerSide
sub r5,r5,$40 ; tile directly above
ldrh r0,[r5] ; "
cmp r0,$1 ;"
beq skipMovePlayerSide
sub r5,r5,$40 ; tile directly above
ldrh r0,[r5] ; "
cmp r0,$1 ;"
beq skipMovePlayerSide
add r3,r3,r4
skipMovePlayerSide:

ldmfd r13!,{r0-r2,r5,r14}
bx r14


playerDLeftPressed:
; In Reg
; r3: horiz scroll amount
;
; Out Reg
; r3: horiz scroll amount
stmfd r13!,{r0-r2,r4,r14}

ldrh r1,[r7,#2] ; OBJ 0 (player) attrib 1

orr r1,r1,%0001000000000000 ; set OBJ horiz flip flag

strh r1,[r7,#2] ; OBJ 0 (player) attrib 1

mov r0,#115 ; x pixel offset: = 112 (player sprite centering) + 3 (left buffer)
mvn r4,#0 ; set player movement for side to -1
bl handlePlayerSideCollision

ldmfd r13!,{r0-r2,r4,r14}
bx r14


playerDRightPressed:
; In Reg
; r3: horiz scroll amount
;
; Out Reg
; r3: horiz scroll amount
stmfd r13!,{r0-r2,r4,r14}

ldrh r1,[r7,#2] ; OBJ 0 (player) attrib 1

mvn r2,%0001000000000000 ; clear OBJ horiz flip flag
and r1,r1,r2 ; "

strh r1,[r7,#2] ; OBJ 0 (player) attrib 1

mov r0,#124 ; x pixel offset: = 112 (player sprite centering) + 12 (left buffer)
mov r4,#1 ; set player movement for side to 1
bl handlePlayerSideCollision

ldmfd r13!,{r0-r2,r4,r14}
bx r14


getTileNearPlayerWithOffset:
; In Reg
; r0: x pixel offset
; r1: y pixel offset
; r2: y-position
; r3: horiz offset
;
; Out Reg
; --
;
; calculate tile offset from $6000800 based on horiz scroll (x), y-pos (y), y pixel offset (ypo), and x pixel offset (xpo):
; $40 (bytes per row) * floor((y + ypo) / 8 (pixels per tile)) + $2 * floor(((x + xpo) & $FF) / 8 (pixels per tile))
; = $40 * ((y + ypo) >> 3) + ((((x + xpo) & $FF) >> 3) << 1)
; = $40 * ((y + ypo + 1) >> 3) + (((x + xpo) & $F8) >> 2)
stmfd r13!,{r4-r6}

add r4,r2,r1
mov r4,r4,lsr #3

add r5,r3,r0
and r5,r5,$F8
mov r5,r5,lsr #2
mov r6,$40
mla r0,r6,r4,r5

ldmfd r13!,{r4-r6}
bx r14


start:
mov r9,$4000000 ; PERSIST

mov r1,%0001000101000000 ; use BG mode 0, 1D char map, turn on BG0, turn on OBJ screen
strh r1,[r9]

mov r1,%0000000100000000 ; use screen base block 1 and use character block base 0
strh r1,[r9,$8]

; transfer player palette data to OBJ palette RAM
adr r1,PlayerPalette
str r1,[r9,$D4] ; DMA 3 source address ($40000D4)

mov r3,$5000000 ; PERSIST FOR BACKGROUND PALETTE
orr r1,r3,$200 ; destination start address: OBJ palette 0 ($5000200)
str r1,[r9,$D8] ; DMA 3 destination start address ($40000D8)

mov r4,%10000100000000000000000000000000 ; PERSIST FOR SPRITE DMA ; (DMA3CNT) Enable DMA with 32-bit transfers
orr r1,r4,#8 ; do 6 32-bit transfers (8 * 32-bit transfers = 16 * 16-bit palette colors)
str r1,[r9,$DC] ; DMA 3 control ($40000DC)

; transfer player idle sprite to VRAM OBJ chars
adr r1,PlayerIdleSprite
str r1,[r9,$D4] ; DMA 3 source address ($40000D4)

mov r8,$6000000 ; PERSIST
orr r1,r8,$10000 ; VRAM OBJ char data ($6010000)
orr r1,r1,$20 ; destination start address: VRAM OBJ char 1 ($6010020)
str r1,[r9,$D8] ; DMA 3 destination start address ($40000D8)

orr r1,r4,#64 ; do 64 32-bit transfers ((16 pixels wide / 8 pixels per row block) * (32 pixels high / 1 pixel per row block))
str r1,[r9,$DC] ; DMA 3 control ($40000DC)


; transfer background palette data to bkgnd palette RAM
adr r1,BackgroundPalette
str r1,[r9,$D4] ; DMA 3 source address ($40000D4)

str r3,[r9,$D8] ; DMA 3 destination start address ($40000D8) (note r3: destination start address: bkgnd palette 0 ($5000000))

orr r1,r4,#3 ; do 6 32-bit transfers (3 * 32-bit transfers = (5 colors + 1 buffer) * 16-bit palette colors)
str r1,[r9,$DC] ; DMA 3 control ($40000DC)

; transfer floor tile to VRAM background chars
adr r1,FloorTile
str r1,[r9,$D4] ; DMA 3 source address ($40000D4)

orr r1,r8,$20 ; VRAM bkgnd tile1 ($6000020)
str r1,[r9,$D8] ; DMA 3 destination start address ($40000D8)

orr r1,r4,#8 ; do 8 32-bit transfers ((8 pixels wide / 8 pixels per row block) * (8 pixels high / 1 pixel per row block))
str r1,[r9,$DC] ; DMA 3 control ($40000DC)

; draw in the floor tiles
mov r1,$1 ; tile # for floor tile
mov r4,$C40 ; bkgnd row 17 start -> offset from $6000000: $800 base offset + (17 rows * $40 bytes per row) = $C40

drawFloorTilesLoop:
cmp r4,$D00 ; compare to row 20 start ($800 base offset + (20 rows * $40 bytes per row)) = $D00
strlth r1,[r8,r4] ; write tile in map
addlt r4,r4,$2 ; next tile
blt drawFloorTilesLoop

mov r4,$C00 ; place single tile above floor in row 16
strh r1,[r8,r4] ; "

sub r4,r4,$3E ; place single tile diagonal to previous block
strh r1,[r8,r4] ; "

add r4,r4,$2 ; place single tile next to previous block
strh r1,[r8,r4] ; "

sub r4,r4,$180 ; place single tile 6 blocks above previous block
strh r1,[r8,r4] ; "


; set up player sprite in OAM
mov r7,$7000000 ; PERSIST

mov r4,%1000000000000000 ; attrib 0: set vertical rectangle shape
;orr r4,r4,#0 ; initial y-position
strh r4,[r7] ; OBJ 0 attrib 0 ($7000000)

mov r4,%1000000000000000 ; attrib 1: set size to 16x32 (%10)
orr r4,r4,#112 ; attrib 1: set x = (240 screen width - 16 player sprite width) / 2 = 112 pixels
strh r4,[r7,#2] ; OBJ 0 attrib 1 ($7000002)

mov r4,%0000000000000001 ; attrib 2: use palette 0 and sprite starts at char 1
strh r4,[r7,#4] ; OBJ 0 attrib 2 ($7000004)

mov r11,r13 ; set frame pointer
mov r4,#0
strb r4,[r11,$0] ; horiz scroll amount (IWRAM)
strb r4,[r11,$1] ; y-velocity
strb r4,[r11,$2] ; player grounded flag

mainLoop:
; Persisting Registers:
; r7: $7000000 (OAM)
; r8: $6000000 (VRAM)
; r9: $4000000 (I/O)
waitForVBlankEnd:
ldrh r0,[r9,$4] ; LCD status
tst r0,#1 ; test if inside v-blank interval
bne waitForVBlankEnd ; try again if inside
waitForVBlankStart:
ldrh r0,[r9,$4] ; LCD status
tst r0,#1 ; test if inside v-blank interval
beq waitForVBlankStart ; try again if not inside


ldrb r3,[r11,$0] ; horiz scroll amount

; handle player input
ldrb r5,[r9,$130] ; key status
; handle player jump
tst r5,%10 ; b
bne skipPlayerBPress
bl playerBPressed
skipPlayerBPress:

; handle player horizontal movement
tst r5,%100000 ; d-left
bne skipPlayerDLeftPress
bl playerDLeftPressed
skipPlayerDLeftPress:

tst r5,%10000 ; d-right
bne skipPlayerDRightPress
bl playerDRightPressed
skipPlayerDRightPress:

strb r3,[r9,$10] ; BG 0 horiz offset
strb r3,[r11,$0] ; horiz scroll amount (IWRAM)


; update player y-pos and velocity
ldrh r4,[r7] ; y-pos (in OBJ 0 attrib 0)
ldrsb r6,[r11,$1] ; y-vel (signed)

mov r2,r6,asr #2 ; apply only a quarter of velocity to the player (almost like treating velocity as a Q6.2 fixed-point number)
add r2,r4,r2
and r2,r2,$FF ; mask only y-pos
and r4,r4,$FF00 ; mask out y-pos

checkPlayerTilemapCollision:
	add r10,r8,$800 ; tilemap block offset

	; check if player is standing on the floor
	mov r1,#32 ; y pixel offset: = h (31 pixels for player sprite height (pixels 0-31)) + 1 pixel (for block below)

	mov r0,#116 ; x pixel offset offset: player left side: = 112 (player sprite centering) + 4 (left buffer)
	bl getTileNearPlayerWithOffset
	ldrh r0,[r10,r0] ; tile directly below player left
	cmp r0,$1 ; check if tile below left is floor tile
	beq floorBelowPlayer

	mov r0,#123 ; x pixel offset: player right side: = 112 (player sprite centering) + 11 (right buffer)
	bl getTileNearPlayerWithOffset
	ldrh r0,[r10,r0] ; tile directly below player right
	cmp r0,$1 ; check if tile below right is floor tile
	beq floorBelowPlayer

noFloorBelowPlayer:
orr r4,r4,r2
add r6,r6,#1
mov r2,#0 ; player is not grounded
b floorCheckEnd
floorBelowPlayer:
and r2,r2,$F8 ; make the player stand flat on the floor (r6 = (r6 & $FF) - (r6 % 8) for r6 >= 0)
orr r4,r4,r2
mov r6,#0 ; zero y-velocity when player is on the floor
mov r2,#1 ; player is grounded
floorCheckEnd:

strb r2,[r11,$2] ; player grounded flag
strb r6,[r11,$1] ; y-vel
strh r4,[r7] ; y-pos (in OBJ 0 attrib 0)

b mainLoop
