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
mov r0,$7000000

mov r1,%1000000000000000 ; attrib 0: set vertical rectangle shape with sprite at y=0
strh r1,[r0] ; OBJ 0 attrib 0 ($7000000)

mov r1,%1000000000000000 ; attrib 1: set size to 16x32 (%10) with sprite at x=0
strh r1,[r0,#2] ; OBJ 0 attrib 1 ($7000002)

mov r1,%0000000000000001 ; attrib 2: use palette 0 and sprite starts at char 1
strh r1,[r0,#4] ; OBJ 0 attrib 2 ($7000004)

; set background to white for now
mov r1,$5000000
mvn r2,#0
strh r2,[r1]

loop:
b loop
