.scope Mapper

.proc Init
    ; TODO: Currently unused

    lda #$80
    sta MAPPER_CTRL ; Reset latch for register writes.
    sta MAPPER_CHR0
    sta MAPPER_CHR1
    sta MAPPER_PRG

    lda #%00001110 ; Set swap mode to vertical mirror. Swappable bank at $8000, on 16KB PRG-ROM. Fixed bank at $C000. 8KB CHR banks.
    jsr SetMode

    ; Clear CHR bank 0 register
    sta MAPPER_CHR0
    sta MAPPER_CHR0
    sta MAPPER_CHR0
    sta MAPPER_CHR0
    sta MAPPER_CHR0

    ; Clear CHR bank 1 register
    sta MAPPER_CHR1
    sta MAPPER_CHR1
    sta MAPPER_CHR1
    sta MAPPER_CHR1
    sta MAPPER_CHR1

    rts
.endproc

;
; params: A = required bank
; returns: none
;
; TODO: Guard against NMI and main thread stomping.
.proc SetPRGBank

    sta MAPPER_PRG
    lsr a
    sta MAPPER_PRG
    lsr a
    sta MAPPER_PRG
    lsr a
    sta MAPPER_PRG
    lsr a
    sta MAPPER_PRG

    rts
.endproc

;
; params: A = required mode
; returns: A = A>>4
.proc SetMode
    sta MAPPER_CTRL
    lsr a
    sta MAPPER_CTRL
    lsr a
    sta MAPPER_CTRL
    lsr a
    sta MAPPER_CTRL
    lsr a
    sta MAPPER_CTRL

    rts
.endproc

.endscope