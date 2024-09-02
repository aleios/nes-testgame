AS := ca65
LD := cl65
AR := ar65
BMP2CHR := python util/bmp2chr.py
EMULATOR := mesen2

ROMNAME := starter
SRC_DIR := src
BUILD_DIR := build
ASSETS_DIR := assets
DATA_DIR := data
CHRROM := tiles.chr

ASFLAGS := -g
LDFLAGS := -g -C nes-nrom.cfg -m memmap.txt -Wl --dbgfile,$(ROMNAME).dbg

SRC := $(SRC_DIR)/main.asm
OBJS := $(patsubst $(SRC_DIR)/%.asm,$(BUILD_DIR)/%.o,$(SRC))

.PHONY: clean
.PHONY: run

all: $(ROMNAME).nes

# Final ROM link
$(ROMNAME).nes: $(DATA_DIR)/$(CHRROM) $(BUILD_DIR)/main.o
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

# Generate tile chr from tiles.bmp in assets.
$(DATA_DIR)/$(CHRROM): $(ASSETS_DIR)/tiles.bmp | $(DATA_DIR)
	$(BMP2CHR) $(DATA_DIR)/$(CHRROM) $(ASSETS_DIR)/tiles.bmp

# Assemble sources
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm | $(BUILD_DIR)
	$(AS) $(ASFLAGS) -o $@ $<

# Make build folder
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Make data folder
$(DATA_DIR):
	mkdir -p $(DATA_DIR)


run: $(ROMNAME).nes
	$(EMULATOR) $(ROMNAME).nes

clean:
	rm -f $(ROMNAME).nes
	rm -rf $(DATA_DIR)
	rm -rf $(BUILD_DIR)
