b start

@i "header.asm"

@i "sprites.asm"
@i "background_tiles.asm"


start:
mov r0,$4000000 ; PERSIST

mov r1,%0001000101000000 ; use BG mode 0, 1D char map, turn on BG0, turn on OBJ screen
strh r1,[r0]

mov r1,%0000000100000000 ; use screen base block 1 and use character block base 0
strh r1,[r0,$8]

; transfer player palette data to OBJ palette RAM
adr r1,PlayerPalette
str r1,[r0,$D4] ; DMA 3 source address ($40000D4)

mov r3,$5000000 ; PERSIST FOR BACKGROUND PALETTE
orr r1,r3,$200 ; destination start address: OBJ palette 0 ($5000200)
str r1,[r0,$D8] ; DMA 3 destination start address ($40000D8)

mov r4,%10000100000000000000000000000000 ; PERSIST FOR SPRITE DMA ; (DMA3CNT) Enable DMA with 32-bit transfers
orr r1,r4,#8 ; do 6 32-bit transfers (8 * 32-bit transfers = 16 * 16-bit palette colors)
str r1,[r0,$DC] ; DMA 3 control ($40000DC)

; transfer player idle sprite to VRAM OBJ chars
adr r1,PlayerIdleSprite
str r1,[r0,$D4] ; DMA 3 source address ($40000D4)

mov r2,$6000000 ; PERSIST
orr r1,r2,$10000 ; VRAM OBJ char data ($6010000)
orr r1,r1,$20 ; destination start address: VRAM OBJ char 1 ($6010020)
str r1,[r0,$D8] ; DMA 3 destination start address ($40000D8)

orr r1,r4,#64 ; do 64 32-bit transfers ((16 pixels wide / 8 pixels per row block) * (32 pixels high / 1 pixel per row block))
str r1,[r0,$DC] ; DMA 3 control ($40000DC)


; transfer background palette data to bkgnd palette RAM
adr r1,BackgroundPalette
str r1,[r0,$D4] ; DMA 3 source address ($40000D4)

str r3,[r0,$D8] ; DMA 3 destination start address ($40000D8) (note r3: destination start address: bkgnd palette 0 ($5000000))

orr r1,r4,#3 ; do 6 32-bit transfers (3 * 32-bit transfers = (5 colors + 1 buffer) * 16-bit palette colors)
str r1,[r0,$DC] ; DMA 3 control ($40000DC)

; transfer floor tile to VRAM background chars
adr r1,FloorTile
str r1,[r0,$D4] ; DMA 3 source address ($40000D4)

orr r1,r2,$20 ; VRAM bkgnd tile1 ($6000020)
str r1,[r0,$D8] ; DMA 3 destination start address ($40000D8)

orr r1,r4,#8 ; do 8 32-bit transfers ((8 pixels wide / 8 pixels per row block) * (8 pixels high / 1 pixel per row block))
str r1,[r0,$DC] ; DMA 3 control ($40000DC)

; draw in the floor tiles
mov r1,$1 ; tile # for floor tile
mov r4,$C40 ; bkgnd row 17 start -> offset from $6000000: $800 base offset + (17 rows * $40 bytes per row) = $C40

drawFloorTilesLoop:
cmp r4,$D00 ; compare to row 20 start ($800 base offset + (20 rows * $40 bytes per row)) = $D00
strlth r1,[r2,r4] ; write tile in map
addlt r4,r4,$2 ; next tile
blt drawFloorTilesLoop

mov r4,$C00 ; add single tile above floor in row 16
strh r1,[r2,r4] ; "


; set up player sprite in OAM
mov r1,$7000000 ; PERSIST

mov r4,%1000000000000000 ; attrib 0: set vertical rectangle shape
;orr r4,r4,#0 ; initial y-position
strh r4,[r1] ; OBJ 0 attrib 0 ($7000000)

mov r4,%1000000000000000 ; attrib 1: set size to 16x32 (%10)
orr r4,r4,#112 ; attrib 1: set x = (240 screen width - 16 player sprite width) / 2 = 112 pixels
strh r4,[r1,#2] ; OBJ 0 attrib 1 ($7000002)

mov r4,%0000000000000001 ; attrib 2: use palette 0 and sprite starts at char 1
strh r4,[r1,#4] ; OBJ 0 attrib 2 ($7000004)

mov r11,r13 ; set frame pointer
mov r4,#0
strb r4,[r11,$0] ; horiz scroll amount (IWRAM)
strb r4,[r11,$1] ; y-velocity
strb r4,[r11,$2] ; player grounded flag

mainLoop:
; Persisting Registers:
; r0: $4000000 (I/O)
; r1: $7000000 (OAM)
; r2: $6000000 (VRAM)
waitForVBlankEnd:
ldrh r4,[r0,$4] ; LCD status
tst r4,#1 ; test if inside v-blank interval
bne waitForVBlankEnd ; try again if inside
waitForVBlankStart:
ldrh r4,[r0,$4] ; LCD status
tst r4,#1 ; test if inside v-blank interval
beq waitForVBlankStart ; try again if not inside

ldrh r4,[r1,#2] ; OBJ 0 (player) attrib 1
ldrb r5,[r11,$0] ; horiz scroll amount

; handle player input
ldrb r3,[r0,$130] ; key status
; handle player jump
ldrb r6,[r11,$2] ; player grounded flag
cmp r6,#1 ; check if player is grounded
bne skipJumpInputCheck
tst r3,%10 ; b
mvneq r6,#12
streqb r6,[r11,$1] ; y-vel
skipJumpInputCheck:

; handle player horizontal movement
tst r3,%100000 ; d-left
orreq r4,r4,%0001000000000000 ; set OBJ horiz flip flag
subeq r5,r5,#1

tst r3,%10000 ; d-right
mvneq r6,%0001000000000000 ; clear OBJ horiz flip flag
andeq r4,r4,r6 ; "
addeq r5,r5,#1

strb r5,[r0,$10] ; BG 0 horiz offset
strh r4,[r1,#2] ; OBJ 0 (player) attrib 1

strb r5,[r11,$0] ; horiz scroll amount (IWRAM)


; update player y-pos and velocity
ldrh r4,[r1] ; y-pos (in OBJ 0 attrib 0)
ldrsb r3,[r11,$1] ; y-vel (signed)

mov r6,r3,asr #2 ; apply only a quarter of velocity to the player (almost like treating velocity as a Q6.2 fixed-point number)
add r6,r4,r6
and r6,r6,$FF ; mask only y-pos
and r4,r4,$FF00 ; mask out y-pos

; check if player is standing on the floor
; calculate tile offset from $6000800 based on horiz scroll (x), y-pos (y), player sprite height (h), and left-right buffer (b). Left-right buffer should be customized to fit the player sprite well so that it looks like they're standing on a ledge when they should be able to (give extra buffer for back so jumps are not as frustrating: "I swear I was standing on the floor!" (was one pixel off)):
; $40 (bytes per row) * floor((y + h + 1 (adding one to find tile below)) / 8 (pixels per tile)) + $2 * floor(((x + 112 (see player sprite centering) + b) & $FF) / 8 (pixels per tile))
; = $40 * ((y + h + 1) >> 3) + ((((x + 112 + b) & $FF) >> 3) << 1)
; = $40 * ((y + h + 1) >> 3) + (((x + 112 + b) & $F8) >> 2)
; NOTE: calculation can simplified to use fewer registers but will take more instructions (instead of mla, multiply as we get values, then add as we get values, thus only needing to store 3 things at one time rather than 4 but at the cost of one extra instruction). Determine based on need for registers later
mov r7,$40
add r8,r6,#33 ; 33 = h (32 pixels tall for player sprite) + 1 pixel
mov r8,r8,lsr #3

add r9,r5,#116 ; player left side: 116 = 112 (player sprite centering) + 4 (left buffer)
and r9,r9,$F8
mov r9,r9,lsr #2
mla r9,r7,r8,r9

add r10,r5,#123 ; player right side: 123 = 112 (player sprite centering) + 11 (right buffer)
and r10,r10,$F8
mov r10,r10,lsr #2
mla r10,r7,r8,r10

add r7,r2,$800 ; tilemap block offset
ldrh r9,[r7,r9] ; tile directly below player left
ldrh r10,[r7,r10] ; tile directly below player right

cmp r9,$1 ; check if tile below left is floor tile
beq floorBelowPlayer
cmp r10,$1 ; check if tile below right is floor tile
beq floorBelowPlayer
noFloorBelowPlayer:
orr r4,r4,r6
add r3,r3,#1
mov r6,#0
b floorCheckEnd
floorBelowPlayer:
and r6,r6,$F8 ; make the player stand flat on the floor (r6 = (r6 & $FF) - (r6 % 8) for r6 >= 0)
orr r4,r4,r6
mov r3,#0
mov r6,#1 ; player is grounded
floorCheckEnd:

strb r6,[r11,$2] ; player grounded flag
strb r3,[r11,$1] ; y-vel
strh r4,[r1] ; y-pos (in OBJ 0 attrib 0)

b mainLoop
