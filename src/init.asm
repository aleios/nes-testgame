.segment "HEADER" ; Header for emulators
    .byte $4E, $45, $53, $1A  ; Magic num
    .byte $02                ; 2x 16KB PRG ROM (32KB)
    .byte $01                ; CHR ROM
    .byte %00000001          ; vertical mirror, no mapper
    .byte $00                ; 

.segment "VECTORS"
    .addr nmi
    .addr reset

.segment "STARTUP"
reset:
    sei ; Set interrupt disable
    cld ; Clear decimal flag

    ldx #$40
    stx $4017 ; Write 0x40 into frame counter register of the APU. Disable APU IRQ

    ldx #$ff
    txs       ; Write 0xFF to set stack pointer.
    inx       ; Wrap X register back to 0.

    stx $2000 ; Disable NMI by setting PPUCTRL to 0 (value in X)
    stx $2001 ; Disable rendering by setting PPUMASK to 0
    stx DMCCTRL ; Disable DMC by setting (DMCCTRL) in APU to 0.

    bit $2002 ; Clear PPUSTATUS vblank state bit.

@vblankwait:
    bit $2002 ;
    bpl @vblankwait

    txa

@clrmem: ; Clear RAM. Range $0000 - $07FF
    lda #0
    sta $000,x
    sta $100,x
    sta $300,x
    sta $400,x
    sta $500,x
    sta $600,x
    sta $700,x

	lda #$FE ; Set to 0xFE to disable sprites
	sta $0200, x

    inx
    bne @clrmem ; Check if X overflowed back to 0. Otherwise keep going.


@vblankwait2: ; Wait on vblank again
    bit $2002
    bpl @vblankwait2

jmp main ; Jump to main loop