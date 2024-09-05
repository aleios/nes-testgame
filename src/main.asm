.include "regs.asm"
.include "init.asm"

.include "joy.asm"

.segment "ZEROPAGE"
; Locals/temporaries
temp_0: .res 1
temp_1: .res 1
temp_2: .res 1
temp_3: .res 1

; Button tracking
frame_counter: .res 1, 0
buttons: .res 1, 0
last_buttons: .res 1, 0
pressed_buttons: .res 1, 0
released_buttons: .res 1, 0

player_x: .res 1
player_y: .res 1
facing_dir: .res 1

ppu_state: .res 1 ; Track changes to $2000 (PPUCTRL)
current_sprite_index: .res 1

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

    ; Face down initially.
    lda #$04
    sta facing_dir

mainloop: ; Infinite loop
    
    jsr ClearShadowOAM
    jsr Joypad::Poll
    jsr CheckPlayerMove
    jsr PushCharaToShadowOAM

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

; Desc: Loads palette values into PPU memory.
; Params: None
; Returns: None
; Modifies: PPU memory
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

; Shamelessly yoinked as solves the same problem.
; Table of offsets based on the combination of buttons pressed. Maps to the lut_CharaSpriteTable below.
; Works out so that horizontal directions take priority over vertical.
lut_FacingMode:
  .BYTE $00,$00,$10,$00,$30,$00,$10,$00,$20,$00,$10,$00,$30,$00,$10,$00

; 2 bytes per sprite. Tile ID and Attributes
; Each character metasprite is 4 sprites. UL, UR, DL, DR
; So each animation frame is 8 bytes.
; 64 bytes total.
lut_CharaSpriteTable:
    ; 0x00
    .byte $09,$40, $08,$40, $0B,$40, $0A,$40 ; Right frame 0
    .byte $0D,$40, $0C,$40, $0F,$40, $0E,$40 ; Right frame 1

    ; 0x10
    .byte $08,$00, $09,$00, $0A,$00, $0B,$00 ; Left frame 0
    .byte $0C,$00, $0D,$00, $0E,$00, $0F,$00 ; Left frame 1

    ; 0x20
    .byte $04,$00, $05,$00, $06,$00, $07,$00 ; Up frame 0
    .byte $05,$40, $04,$40, $07,$40, $06,$40 ; Up frame 1

    ; 0x30
    .byte $00,$00, $01,$00, $02,$00, $03,$00 ; Down frame 0
    .byte $00,$00, $01,$00, $03,$40, $02,$40 ; Down frame 1

; Desc: Pushes a 4x4 metasprite to Shadow OAM.
; Params:
;   A - Frame counter
;   temp_0 - Low byte of sprite table
;   temp_1 - High byte of sprite table
;   temp_2 - X position
;   temp_3 - Y position
; Returns: none
; Modifies: current_sprite_index
; TODO: Move fixed logic outside this function. Provide the params so can be used in generic way.
.proc PushCharaToShadowOAM

    and #$08
    
    ; Get the facing direction
    ldx facing_dir
    ora lut_FacingMode, x
    sta temp_0

    lda #<lut_CharaSpriteTable
    clc
    adc temp_0
    sta temp_0 ; Low byte of chara-table address

    lda #>lut_CharaSpriteTable
    adc #0
    sta temp_1 ; High byte of chara-table address

    ; Offset at current_sprite_index bytes.
    ldx current_sprite_index

    ; Set Y-positions of the metasprite. UL, UR, BL, BR
    lda #108 ; Player start at Y-108
    sta OAM_OFFSET+$00, x
    sta OAM_OFFSET+$04, x
    clc
    adc #$08
    sta OAM_OFFSET+$08, x
    sta OAM_OFFSET+$0c, x

    ; Set X-positions of the metasprite. UL, BL, UR, BR
    lda #116
    sta OAM_OFFSET+$03, x
    sta OAM_OFFSET+$0B, x
    clc
    adc #$08
    sta OAM_OFFSET+$07, x
    sta OAM_OFFSET+$0F, x

    ; Find and set tile indices and attributes for sprites.
    ldy #0

    ; UL
    lda (temp_0), y
    iny
    sta OAM_OFFSET+$01, x
    lda (temp_0), y
    iny
    sta OAM_OFFSET+$02, x

    ; UR
    lda (temp_0), y
    iny
    sta OAM_OFFSET+$05, x
    lda (temp_0), y
    iny
    sta OAM_OFFSET+$06, x

    ; BL
    lda (temp_0), y
    iny
    sta OAM_OFFSET+$09, x
    lda (temp_0), y
    iny
    sta OAM_OFFSET+$0A, x

    ; BR
    lda (temp_0), y
    iny
    sta OAM_OFFSET+$0D, x
    lda (temp_0), y
    iny
    sta OAM_OFFSET+$0E, x


    ; Increment sprite index by 16bytes. 4 bytes per OAM entry with 4 entries per metasprite.
    lda current_sprite_index
    clc
    adc #$10
    sta current_sprite_index
    rts

.endproc

; Desc: Clears Shadow OAM values to 0xFE. Effectively hiding the sprites.
; Params: None
; Returns: None
; Modifies: current_sprite_index
.proc ClearShadowOAM

    ; Loop over all 64 sprites and clear them to $FE similar to init.
    ldx #$3F
    lda #$FE

    @loop:
        sta $0200, x
        sta $0240, x
        sta $0280, x
        sta $02C0, x
        dex 
        bpl @loop ; Loop until reached end.

    ; Reset current sprite index back to 0.
    lda #0
    sta current_sprite_index
    rts
.endproc

;------------------------------
; Nametable
;------------------------------

; Desc: Fully clears nametable 1 to 0x0 including attribute table.
; Params: None
; Returns: None
; Modifies: PPU memory
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

; Desc: Fully clears nametable 2 to 0x0 including attribute table.
; Params: None
; Returns: None
; Modifies: PPU memory
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

; Desc: Commit new scroll values on the PPU
; Params: None
; Returns: None
; Modifies: PPU registers
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

; Desc: Checks the current button state and if the player character is moving.
; Params: None
; Returns: None
; Modifies: facing_dir, player_x, player_y, ppu_state
.proc CheckPlayerMove
    ; Check buttons and mask the dpad bits.
    lda buttons
    and #$0F
    bne @doMovement
    rts

    ; Cycle through each dpad case until we get a match.
@doMovement:
    sta facing_dir
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
    lda player_x ; TODO: Remove. Anim counter should be its own thing instead of relying on fallthrough.
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