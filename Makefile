SRC_DIR=src
CC=gcc
BUILD_DIR=build
TOOLD_DIR=tools
ASM=nasm

.PHONY: all floppy_image kernal bootloader clean always tools_fat

all: floppy_image tools_fat

#
# Build floppy image
#

floppy_image: $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader kernal
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "NBOS" $(BUILD_DIR)/main_floppy.img
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernal.bin "::kernal.bin"
	mcopy -i $(BUILD_DIR)/main_floppy.img test.txt "::test.txt"


#
# Boot Loader
#
bootloader: $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/bootloader.bin: always
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin


#
# kernal
#
kernal: $(BUILD_DIR)/kernal.bin

$(BUILD_DIR)/kernal.bin: always
	$(ASM) $(SRC_DIR)/kernal/main.asm -f bin -o $(BUILD_DIR)/kernal.bin



#
# Tools
#
tools_fat: $(BUILD_DIR)/tools/fat
$(BUILD_DIR)/tools/fat: always $(TOOLD_DIR)/fat/fat.c
	mkdir -p $(BUILD_DIR)/tools
	$(CC) -g -o $(BUILD_DIR)/tools/fat $(TOOLD_DIR)/fat/fat.c

#
# Always
#

always:
	mkdir -p $(BUILD_DIR)

#
# Clean
#
clean:
	rm -rf $(BUILD_DIR)/*
