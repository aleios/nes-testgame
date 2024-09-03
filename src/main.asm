.include "regs.asm"
.include "init.asm"

.include "joy.asm"

.segment "ZEROPAGE"
frame_counter: .res 1, 0
buttons: .res 1, 0
last_buttons: .res 1, 0
pressed_buttons: .res 1, 0
released_buttons: .res 1, 0

player_x: .res 1
player_y: .res 1
facing_dir: .res 1

ppu_state: .res 1 ; Track changes to $2000 (PPUCTRL)

.segment "CHR"
	.incbin "../data/tiles.chr"

.segment "BSS"

    game_state: .res 1

.segment "RODATA"

; Static palette
palette:
	.byte $0F,$00,$10,$30, $0F,$00,$10,$30, $0F,$00,$10,$30, $0F,$00,$10,$30 ; BG palettes
	.byte $0F,$07,$25,$37, $0F,$00,$10,$30, $0F,$00,$10,$30, $0F,$00,$10,$30 ; Sprite palettes

; Hello, world message
message:
    .byte $13, $10, $17, $17, $1A, $00, $22, $1A, $1D, $17, $0F ; H E L L O  W O R L D
message_len:
    .byte $0B

.segment "CODE"

;------------------------------
; Entry point
;------------------------------
.proc main

    jsr LoadPalette    ; Load in palette
    jsr ClearNametable ; Fully clear the nametable.
    jsr ClearNametable2
    jsr DisplayHelloWorld    ; Create 'HELLO WORLD' on nametable

    lda #%10010000 ; Renable render
    sta $2000

    lda #%00011110
    sta $2001

    jsr Joypad::Init ; Init joypad

    lda #$0
    sta player_x
    sta player_y

mainloop: ; Infinite loop

    jsr Joypad::Poll
    jsr CheckPlayerMove
    jsr UpdateShadowOAM

    lda frame_counter
@waitForNMI: ; Spin until next frame.
    cmp frame_counter
    beq @waitForNMI

    jmp mainloop
.endproc
    
;------------------------------
; NMI VBlank routine
;------------------------------
.proc nmi

    ; Stack save
    pha
    txa
    pha
    tya
    pha

    ; Copy shadow OAM to PPU OAM
    lda #$00 ; Write 0x0 to OAMADDR
    sta OAMADDR

    lda #$02 ; Write 0x02 to OAMDMA. 0x02 because our OAM is located at 0x0200.
    sta OAMDMA

    ;
	lda #0
	sta $2006
	sta $2006

    ; Update scroll
    lda player_x ; TODO: Switch scroll to using tile based. Arithmatic shift left to get the final scroll value.
    sta PPUSCROLL
    lda player_y
    sta PPUSCROLL

    ; turn on background
    lda #$0A
    sta $2001

    ; Turn on NMI. Combine with nametable state.
    lda ppu_state
    ora #%10010000
    sta $2000

    ; Turn on rendering
    lda #%00011110
    sta PPUMASK

    ; Increment frame counter, signalling the main loop that a new frame is ready.
    inc frame_counter

    ; Stack restore
    pla
    tay
    pla
    tax
    pla
    rti ; Return from interrupt
.endproc
    
;------------------------------
; Palette
;------------------------------
.proc LoadPalette

    lda PPUSTATUS ; Enable writing to PPU but reading PPUSTATUS

    lda #$3F ; Write Palette address 0x3F00
    sta PPUADDR
    lda #$00
    sta PPUADDR

@loop: ; Write each byte of the palette to PPU

	lda palette, x ; Load palette index at X
	
	sta PPUDATA    ; Store palette to data.
	
	inx
	cpx #32
	bne @loop
	
	rts
.endproc

;------------------------------
; Tiles
;------------------------------

;------------------------------
; OAM
;------------------------------

; TODO: Push sprites rather than fixed location in OAM.
.proc UpdateShadowOAM

    ; Byte 0 = Y-value
    ; Byte 1 = Tile index. 8x8 mode.
    ; Byte 2 = Attribs. 76543210
    ;                   ++*---^^
    ; + = mirror bits
    ; * = priority
    ; ^ = palette index
    ; Byte 3 = X-value

    ; Player sprite top-left
    lda #108 ; Y-value
    sta $200
    lda #0
    sta $201
    sta $202
    lda #116 ; X-value
    sta $203

    ; Player sprite top-right
    lda #108
    sta $204
    lda #1
    sta $205
    lda #0
    sta $206
    lda #124
    sta $207

    ; player sprite bottom-left
    lda #116
    sta $208
    lda #2
    sta $209
    lda #0
    sta $20A
    lda #116
    sta $20B

    ; player sprite bottom-right
    lda #116
    sta $20C
    lda #3
    sta $20D
    lda #0
    sta $20E
    lda #124
    sta $20F

    rts
.endproc

;------------------------------
; Nametable
;------------------------------

.proc ClearNametable

    lda PPUSTATUS ; Trigger address latch on PPU

    lda #$20; Address part
    sta PPUADDR
    lda #$00
    sta PPUADDR

    ; Clear tiles indices.
    ldx #0
    ldy #>($3C0) ; Takes the high byte. So will be 0x03 loaded to Y register. Nametable 'tile id' offset
@clearTileIds:
    sta PPUDATA
    inx
    bne @clearTileIds
    dey
    bne @clearTileIds

    ; Clear attributes
    ldy #<($3C0) ; Takes the low byte. So will be 0xC0 loaded to Y register. Attribute table offset.
@clearAttribs:
    sta PPUDATA
    dey
    bne @clearAttribs

    rts
.endproc

.proc ClearNametable2

    lda PPUSTATUS ; Trigger address latch on PPU

    lda #$24; Address part
    sta PPUADDR
    lda #$00
    sta PPUADDR

    ; Clear tiles indices.
    ldx #0
    ldy #>($3C0) ; Takes the high byte. So will be 0x03 loaded to Y register. Nametable 'tile id' offset
@clearTileIds:
    sta PPUDATA
    inx
    bne @clearTileIds
    dey
    bne @clearTileIds

    ; Clear attributes
    ldy #<($3C0) ; Takes the low byte. So will be 0xC0 loaded to Y register. Attribute table offset.
@clearAttribs:
    sta PPUDATA
    dey
    bne @clearAttribs

    rts
.endproc

.proc UpdateScroll
    lda player_x ; TODO: Switch scroll to using tile based. Arithmatic shift left to get the final scroll value.
    sta PPUSCROLL
    lda player_y
    sta PPUSCROLL

    ; turn on background
    lda #$0A
    sta $2001

    rts

.endproc

.proc CheckPlayerMove
    lda #14
    asl a
    asl a
    asl a
    asl a


    ; Check buttons and mask the dpad bits.
    lda buttons
    and #$0F

    ; Cycle through each dpad case until we get a match.
    lsr a
    bcs @right
    lsr a
    bcs @left
    lsr a
    bcs @down
    lsr a
    bcs @up

    rts ; No dpad match. Return.

;--
; Handle horizontal movement
;--
@right:
    inc player_x
    beq @flipnametable ; Check if we wrapped around to $00 from $FF. If we did then flip the nametable.
    rts
@left:
    lda player_x
    beq @underflow ; If player_x is $00 then it will wraparound to $FF.
    dec player_x   ; If we got there then it didn't wraparound. So we dont flip the nametable.
    rts            ; Return
@underflow:
    dec player_x   ; We got here from @left, which means we wrapped to $FF. Fallthrough to @flipnametable.

@flipnametable:
    lda ppu_state  ; Load the current ctrl state.
    eor #$01             ; Flip the nametable bits.
    sta ppu_state  ; store the new state.
    rts                  ; Return

;--
; Handle vertical movement
;  - Have to do some additional handling, to not get garbage from attrib table.
;--
@down:
    inc player_y
    lda player_y
    cmp #$EF
    bcc @skipdownwrap
    lda #$00
    sta player_y
@skipdownwrap:
    rts             ; Return
@up:
    lda player_y
    beq @yunderflow
    dec player_y
    rts
@yunderflow:
    lda #$EF
    sta player_y
    rts
.endproc

.proc DisplayHelloWorld

	lda $2002 ; Unhook address latch
	lda #$20
	sta $2006
	lda #$4B
	sta $2006
	
    ldx #$0
@loop:
    lda message, x
    sta $2007
    inx
    cpx message_len
    bne @loop
	
	rts
.endproc