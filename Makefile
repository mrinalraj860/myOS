SRC_DIR=src
BUILD_DIR=build
ASM=nasm

.PHONY: all floppy_image kernal bootloader clean always

#
# Build floppy image
#

floppy_image: $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader kernal
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "NBOS" $(BUILD_DIR)/main_floppy.img
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernal.bin "::kernal.bin"


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
# Always
#

always:
	mkdir -p $(BUILD_DIR)

#
# Clean
#
clean:
	rm -rf $(BUILD_DIR)/*
