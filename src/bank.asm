.scope Mapper

.proc Setup

    lda #$80
    sta $9FFF ; Reset latch for register writes.
    sta $BFFF
    sta $DFFF
    sta $FFF9

    lda #%00001110 ; Set swap mode to vertical mirror. Swappable bank at $8000, on 16KB PRG-ROM. Fixed bank at $C000. 8KB CHR banks.
    jsr SetMode

    sta $BFFF ; Put mapper into a known state. A register is 0x00 here.
    sta $BFFF
    sta $BFFF
    sta $BFFF
    sta $BFFF
    sta $DFFF
    sta $DFFF
    sta $DFFF
    sta $DFFF
    sta $DFFF

.endproc

.proc SetPRGBank

    sta MAPREG3
    lsr a
    sta MAPREG3
    lsr a
    sta MAPREG3
    lsr a
    sta MAPREG3
    lsr a
    sta MAPREG3

    rts

.endproc

;
; params: A = required mode
; returns: A = A>>4
.proc SetMode
    sta MAPREG0
    lsr a
    sta MAPREG0
    lsr a
    sta MAPREG0
    lsr a
    sta MAPREG0
    lsr a
    sta MAPREG0

    rts
.endproc

.endscope