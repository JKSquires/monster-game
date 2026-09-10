b start

@i "header.asm"

@i "sprites.asm"
@i "background_tiles.asm"

start:
mov r0,$4000000

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

mov r2,%10000100000000000000000000000000 ; PERSIST FOR SPRITE DMA ; (DMA3CNT) Enable DMA with 32-bit transfers
orr r1,r2,#6 ; do 6 32-bit transfers (6 * 32-bit transfers = 12 * 16-bit palette colors)
str r1,[r0,$DC] ; DMA 3 control ($40000DC)

; transfer player idle sprite to VRAM OBJ chars
adr r1,PlayerIdleSprite
str r1,[r0,$D4] ; DMA 3 source address ($40000D4)

mov r4,$6000000 ; PERSIST FOR BACKGROUND TILES
orr r1,r4,$10000 ; VRAM OBJ char data ($6010000)
orr r1,r1,$20 ; destination start address: VRAM OBJ char 1 ($6010020)
str r1,[r0,$D8] ; DMA 3 destination start address ($40000D8)

orr r1,r2,#64 ; do 64 32-bit transfers ((16 pixels wide / 8 pixels per row block) * (32 pixels high / 1 pixel per row block))
str r1,[r0,$DC] ; DMA 3 control ($40000DC)


; transfer background palette data to bkgnd palette RAM
adr r1,BackgroundPalette
str r1,[r0,$D4] ; DMA 3 source address ($40000D4)

str r3,[r0,$D8] ; DMA 3 destination start address ($40000D8) (note r3: destination start address: bkgnd palette 0 ($5000000))

orr r1,r2,#3 ; do 6 32-bit transfers (3 * 32-bit transfers = (5 colors + 1 buffer) * 16-bit palette colors)
str r1,[r0,$DC] ; DMA 3 control ($40000DC)

; transfer floor tile to VRAM background chars
adr r1,FloorTile
str r1,[r0,$D4] ; DMA 3 source address ($40000D4)

orr r1,r4,$20 ; VRAM bkgnd tile1 ($6000020)
str r1,[r0,$D8] ; DMA 3 destination start address ($40000D8)

orr r1,r2,#8 ; do 8 32-bit transfers ((8 pixels wide / 8 pixels per row block) * (8 pixels high / 1 pixel per row block))
str r1,[r0,$DC] ; DMA 3 control ($40000DC)

; draw in the floor tiles
mov r1,$1 ; tile # for floor tile
mov r2,$C40 ; bkgnd row 17 start -> offset from $6000000: $800 base offset + (17 rows * $40 bytes per row) = $C40

drawFloorTilesLoop:
cmp r2,$D00 ; compare to row 20 start ($800 base offset + (20 rows * $40 bytes per row)) = $D00
strlth r1,[r4,r2] ; write tile in map
addlt r2,r2,$2 ; next tile
blt drawFloorTilesLoop


; set up player sprite in OAM
mov r1,$7000000

mov r2,%1000000000000000 ; attrib 0: set vertical rectangle shape
orr r2,r2,#104 ; attrib 0: set y = 160 screen height - 3 * 8 pixels per tile - 32 player sprite height = 104 pixels
strh r2,[r1] ; OBJ 0 attrib 0 ($7000000)

mov r2,%1000000000000000 ; attrib 1: set size to 16x32 (%10)
orr r2,r2,#112 ; attrib 1: set x = (240 screen width - 16 player sprite width) / 2 = 112 pixels
strh r2,[r1,#2] ; OBJ 0 attrib 1 ($7000002)

mov r2,%0000000000000001 ; attrib 2: use palette 0 and sprite starts at char 1
strh r2,[r1,#4] ; OBJ 0 attrib 2 ($7000004)

mainLoop:
waitForVBlankEnd:
ldrh r2,[r0,$4] ; LCD status
tst r2,#1 ; test if inside v-blank interval
bne waitForVBlankEnd ; try again if inside
waitForVBlankStart:
ldrh r2,[r0,$4] ; LCD status
tst r2,#1 ; test if inside v-blank interval
beq waitForVBlankStart ; try again if not inside

ldrh r2,[r1,#2] ; OBJ 0 (player) attrib 1

; handle player facing direction
ldrb r3,[r0,$130] ; key status
tst r3,%100000 ; d-left
orreq r2,r2,%0001000000000000 ; set OBJ horiz flip flag

tst r3,%10000 ; d-right
mvneq r4,%0001000000000000 ; clear OBJ horiz flip flag
andeq r2,r2,r4 ; "

strh r2,[r1,#2] ; OBJ 0 (player) attrib 1

b mainLoop
