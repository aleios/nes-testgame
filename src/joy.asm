;------------------------------
; Joypad Handlers
;------------------------------
.scope Joypad

.proc Init

    lda #$00
    sta buttons
    sta last_buttons
    sta pressed_buttons
    sta released_buttons

    rts

.endproc

.proc Poll
    lda #$01           ; Write 0x01 to A.
    sta JOY1           ; Write A to JOY1 register. Enable latch, strobe.
    sta buttons        ; initialize buttons to 0x01. This way we can check for 'end' in carry flag in the loop when `rol` puts moves it into carry.
    lsr a              ; Right shift A register back to 0.
    sta JOY1           ; Write A to JOY1 register. Disable latch finishing strobe.

loop:
    lda JOY1    ; Load value from JOY1 register into A
    lsr a       ; Place first bit of A into carry flag.
    rol buttons ; Shift carry flag into `buttons`. Will move the initial `1` left by a position.
    bcc loop    ; Check if new carry flag has the stop bit. If not, loop again!

    ; Get newly pressed buttons
    lda last_buttons
    eor #%11111111
    and buttons
    sta pressed_buttons

    ; Get newly released buttons
    lda buttons
    eor #%11111111
    and last_buttons
    sta released_buttons

    ; Store current button state for next frame
    lda buttons
    sta last_buttons

    rts                    ; return from subroutine
.endproc

.endscope