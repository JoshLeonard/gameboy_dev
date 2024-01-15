INCLUDE "hardware.inc"

DEF BallX EQU $FE00 + $05
DEF BallY EQU $FE00 + $04

SECTION "Header", ROM0[$100]

    jp EntryPoint

    ds $150 - @, 0

EntryPoint:

WaitVBlank:
    ld a, [rLY]
    cp 144
    jp c, WaitVBlank

    ld a, 0
    ld [rLCDC], a

    ld de, Tiles
    ld hl, $9000
    ld bc, TilesEnd - Tiles
	call Memcopy

    ld de, Tilemap
    ld hl, $9800
    ld bc, TilemapEnd- Tilemap
	call Memcopy
	
	ld de, Paddle
	ld hl, $8000
	ld bc, PaddleEnd - Paddle
	call Memcopy

	ld de, Ball
	ld hl, $8010
	ld bc, BallEnd - Ball
	call Memcopy

	ld a, 0
	ld b, 160
	ld hl, _OAMRAM
ClearOam:
	ld [hl+], a
	dec b
	jp nz,  ClearOam

	; Write paddle to oam
	ld hl, _OAMRAM
	ld a, 142
	ld [hl+], a
	ld a, 16 + 8
	ld [hl+], a
	ld a, 0
	ld [hl+], a
	ld [hl+], a

	; Write ball to oam
	ld a, 100 + 16
	ld [hl+], a ; y pos
	ld a, 32 + 8
	;ld [hl+], a ; x pos
	ld [BallX], a
	inc hl
	ld a, 1 
	ld [hl+], a ; tile id
	ld a, 0
	ld [hl], a ; attributes

	ld a, 1
	ld [wBallMomentumX], a
	ld a, -1
	ld [wBallMomentumY], a

    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ld [rLCDC], a

	ld a, %11100100
    ld [rBGP], a
	ld a, %11100100
	ld [rOBP0], a

	ld a, 0
	ld [wFrameCounter], a

Main:
	ld a, [rLY]
	cp 144
	jp nc, Main
WaitVBlank2:
	ld a, [rLY]
	cp 144
	jp c, WaitVBlank2

	; ld a, [wFrameCounter]
	; inc a
	; ld [wFrameCounter], a
	; cp a, 15
	; jp nz, Main

	; ld a, 0
	; ld [wFrameCounter], a
	call UpdateBall
	call UpdateKeys

CheckLeft:
	ld a, [wCurKeys]
	and a, PADF_LEFT
	jp z, CheckRight
Left:
	ld a, [_OAMRAM + 1]
	dec a
	cp a, 15
	jp z, Main
	ld [_OAMRAM + 1], a
	jp Main

CheckRight:
	ld a, [wCurKeys]
	and a, PADF_RIGHT
	jp z, Main
Right:
	ld a, [_OAMRAM + 1]
	inc a
	cp a, 105
	jp z, Main
	ld [_OAMRAM + 1], a
	jp Main

    jp Main

; Copy bytes from one area to another
; @param de: Source
; @param hl: Destination
; @param bc: Length
Memcopy:
	ld a, [de]
	ld [hl+], a
	inc de
	dec bc
	ld a, b
	or a, c
	jr nz, Memcopy
	ret
	
UpdateKeys:
	; Poll half the controller
	ld a, P1F_GET_BTN
	call .onenibble
	ld b, a ; B7-4 = 1; B3-0 = unpressed buttons

	; Poll the other half
	ld a, P1F_GET_DPAD
	call .onenibble
	swap a ; A3-0 = unpressed directions; A7-4 = 1
	xor a, b ; A = pressed buttons + directions
	ld b, a ; B = pressed buttons + directions

	; And release the controller
	ld a, P1F_GET_NONE
	ldh [rP1], a

	; Combine with previous wCurKeys to make wNewKeys
	ld a, [wCurKeys]
	xor a, b ; A = keys that changed state
	and a, b ; A = keys that changed to pressed
	ld [wNewKeys], a
	ld a, b
	ld [wCurKeys], a
	ret

.onenibble
	ldh [$0], a ; switch the key matrix
	call .knownret ; burn 10 cycles calling a known ret
	ldh a, [$0] ; ignore value while waiting for the key matrix to settle
	ldh a, [$0]
	ldh a, [$0] ; this read counts
	or a, $F0 ; A7-4 = 1; A3-0 = unpressed keys
.knownret
	ret

UpdateBall:
	ld a, [wFrameCounter]
	inc a
	ld [wFrameCounter], a
	cp 15
	ret nz
	ld a, 0
.x:	
	ld [wFrameCounter], a
	ld a, [BallX]
	ld hl, wBallMomentumX
	add a, [hl]
	ld [BallX], a
	cp 105
	jp nz, .xcon ; revere vloc if ball hits wall
	ld a, -1
	ld hl, wBallMomentumX
	ld [hl], a
.xcon:
	cp 15
	jp nz, .y
	ld a, 1
	ld hl, wBallMomentumX
	ld [hl], a
.y:
	ld a, [BallY]
	ld hl, wBallMomentumY
	add a, [hl]
	ld [BallY], a
.knownret
	ret

; Convert Pixel position to a tilemap address
; hl = $9800 + X + Y * 32
; @param b: X
; @param c: Y
; @return hl: tile address
GetTileByPixel:
	ld a, c
	and a, %11111000
	ld l, a
	ld h, 0
	add hl, hl
	add hl, hl
	
	ld a, b
	srl a
	srl a
	srl a

	add a, l
	ld l, a
	adc a, h
	sub a, l
	ld h, a
	ld bc, $9800
	add hl, bc
	ret

	IsWallTile:
    cp a, $00
    ret z
    cp a, $01
    ret z
    cp a, $02
    ret z
    cp a, $04
    ret z
    cp a, $05
    ret z
    cp a, $06
    ret z
    cp a, $07
    ret



Tiles:
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33322222
	dw `33322222
	dw `33322222
	dw `33322211
	dw `33322211
	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11111111
	dw `11111111
	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222333
	dw `22222333
	dw `22222333
	dw `11222333
	dw `11222333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `22222222
	dw `20000000
	dw `20111111
	dw `20111111
	dw `20111111
	dw `20111111
	dw `22222222
	dw `33333333
	dw `22222223
	dw `00000023
	dw `11111123
	dw `11111123
	dw `11111123
	dw `11111123
	dw `22222223
	dw `33333333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `11001100
	dw `11111111
	dw `11111111
	dw `21212121
	dw `22222222
	dw `22322232
	dw `23232323
	dw `33333333
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222211
	dw `22222211
	dw `22222211
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11111111
	dw `11111111
	dw `11221111
	dw `11221111
	dw `11000011
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11222222
	dw `11222222
	dw `11222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222211
	dw `22222200
	dw `22222200
	dw `22000000
	dw `22000000
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11000011
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11000022
	dw `11222222
	dw `11222222
	dw `11222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222200
	dw `22222200
	dw `22222211
	dw `22222211
	dw `22221111
	dw `22221111
	dw `22221111
	dw `11000022
	dw `00112222
	dw `00112222
	dw `11112200
	dw `11112200
	dw `11220000
	dw `11220000
	dw `11220000
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22000000
	dw `22000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11110022
	dw `11110022
	dw `11110022
	dw `22221111
	dw `22221111
	dw `22221111
	dw `22221111
	dw `22221111
	dw `22222211
	dw `22222211
	dw `22222222
	dw `11220000
	dw `11110000
	dw `11110000
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `22222222
	dw `00000000
	dw `00111111
	dw `00111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `22222222
	dw `11110022
	dw `11000022
	dw `11000022
	dw `00002222
	dw `00002222
	dw `00222222
	dw `00222222
	dw `22222222
TilesEnd:

Tilemap:
	db $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0A, $0B, $0C, $0D, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0E, $0F, $10, $11, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $12, $13, $14, $15, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $16, $17, $18, $19, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
TilemapEnd:

Paddle:
    dw `13333331
    dw `30000003
    dw `13333331
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
PaddleEnd:

Ball:
    dw `00033000
    dw `00322300
    dw `03222230
    dw `03222230
    dw `00322300
    dw `00033000
    dw `00000000
    dw `00000000
BallEnd:




SECTION "Counter", wram0
wFrameCounter: db

SECTION "Input Variables", wram0
wCurKeys: db
wNewKeys: db

SECTION "Ball Counter", wram0
wBallMomentumX: db
wBallMomentumY: db
