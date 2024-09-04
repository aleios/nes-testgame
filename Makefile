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

ASFLAGS := -g --create-dep $(BUILD_DIR)/main.d
LDFLAGS := -g -C nes-mmc1.cfg -m memmap.txt -Wl --dbgfile,$(ROMNAME).dbg

SRC := $(SRC_DIR)/main.asm
DEPS := $(BUILD_DIR)/main.d
OBJS := $(BUILD_DIR)/main.o

.PHONY: clean
.PHONY: run

all: $(ROMNAME).nes

# Final ROM link
$(ROMNAME).nes: $(DATA_DIR)/$(CHRROM) $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

# Generate tile chr from tiles.bmp in assets.
$(DATA_DIR)/$(CHRROM): $(ASSETS_DIR)/tiles.bmp | $(DATA_DIR)
	$(BMP2CHR) $(DATA_DIR)/$(CHRROM) $(ASSETS_DIR)/tiles.bmp

# Assemble sources
$(BUILD_DIR)/main.o: $(SRC) | $(BUILD_DIR)
	$(AS) $(ASFLAGS) -o $@ $<

# Make build folder
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Make data folder
$(DATA_DIR):
	mkdir -p $(DATA_DIR)

-include $(DEPS)

run: $(ROMNAME).nes
	$(EMULATOR) $(ROMNAME).nes

clean:
	rm -f $(ROMNAME).nes
	rm -rf $(DATA_DIR)
	rm -rf $(BUILD_DIR)
