
; PPU registers
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
PPUSCROLL = $2005

PPUADDR   = $2006
PPUDATA   = $2007

OAMADDR   = $2003
OAMDMA    = $4014

; Joypad registers
JOY1 = $4016
JOY2 = $4017

; APU registers
APUSTATUS   = $4015

PULSE1CTRL = $4000
PULSE1SWEEP = $4001
PULSE1LO = $4002    ; Low bits of the period
PULSE1HI = $4003    ; High bits of period + length counter. 76543210
                    ;                                       -----+++
                    ; - = length counter, + = hi bits of period

PULSE2CTRL = $4004
PULSE2SWEEP = $4005
PULSE2LO = $4006
PULSE2HI = $4007

TRICTRL = $4008
TRILO = $400A
TRIHI = $400B

NOISECTRL = $400C
NOISETIMR = $400E
NOISECNTR = $400F

DMCCTRL = $4010

; Mapper MM1 registers
MAPREG0 = $9FFF ; Use for MMC states. 
                ; Bit 0 = vert/horiz mirroring. 
                ; Bit 1 = one screen / HV mirroring
                ; Bit 2 = high / low PRG rom switching
                ; Bit 3 = 32KB/16KB PRG-ROM bank switching modes.
                ; Bit 4 = 8KB/4KB CHR-ROM mode.

MAPREG1 = $BFFF ; Use for CHR-ROM banks
MAPREG2 = $DFFF ; Use for CHR-ROM banks
MAPREG3 = $FFF9 ; Use to swap PRG-ROM banks

; Buttons
BUTTON_A      = 1 << 7
BUTTON_B      = 1 << 6
BUTTON_SELECT = 1 << 5
BUTTON_START  = 1 << 4
BUTTON_UP     = 1 << 3
BUTTON_DOWN   = 1 << 2
BUTTON_LEFT   = 1 << 1
BUTTON_RIGHT  = 1 << 0

; Offsets
OAM_OFFSET = $200