b start

@i "header.asm"

@i "player_sprites.asm"

start:
mov r0,$4000000

mov r1,%0001000001000000 ; use BG mode 0, 1D char map, turn on OBJ screen
strh r1,[r0]

; transfer player palette data to OBJ palette RAM
adr r1,PlayerPalette
str r1,[r0,$D4] ; DMA 3 source address ($40000D4)

mov r1,$5000000
orr r1,r1,$200 ; destination start address: OBJ palette 0 ($5000200)
str r1,[r0,$D8] ; DMA 3 destination start address ($40000D8)

mov r2,%10000100000000000000000000000000 ; PERSIST FOR SPRITE DMA ; (DMA3CNT) Enable DMA with 32-bit transfers
orr r1,r2,#6 ; do 6 32-bit transfers (6 * 32-bit transfers = 12 * 16-bit palette colors)
str r1,[r0,$DC] ; DMA 3 control ($40000DC)

; transfer player idle sprite to VRAM OBJ chars
adr r1,PlayerIdleSprite
str r1,[r0,$D4] ; DMA 3 source address ($40000D4)

mov r1,$6000000
orr r1,r1,$10000 ; VRAM OBJ char data ($6010000)
orr r1,r1,$20 ; destination start address: VRAM OBJ char 1 ($6010020)
str r1,[r0,$D8] ; DMA 3 destination start address ($40000D8)

orr r1,r2,#64 ; do 64 32-bit transfers ((16 pixels wide / 8 pixels per row block) * (32 pixels high / 1 pixel per row block))
str r1,[r0,$DC] ; DMA 3 control ($40000DC)

; set up player sprite in OAM
mov r1,$7000000

mov r2,%1000000000000000 ; attrib 0: set vertical rectangle shape
orr r2,r2,#64 ; attrib 0: set y = 80 - (32/2) = 64
strh r2,[r1] ; OBJ 0 attrib 0 ($7000000)

mov r2,%1000000000000000 ; attrib 1: set size to 16x32 (%10)
orr r2,r2,#112 ; attrib 1: set y = 120 - (16/2) = 112
strh r2,[r1,#2] ; OBJ 0 attrib 1 ($7000002)

mov r2,%0000000000000001 ; attrib 2: use palette 0 and sprite starts at char 1
strh r2,[r1,#4] ; OBJ 0 attrib 2 ($7000004)

; set background to white for now
mov r2,$5000000
mvn r3,#0
strh r3,[r2]

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
