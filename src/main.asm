org 0x7C00
bits 16

start:
    jmp main

;  Prints a string to the string
;  Input:
;   ds:si - pointer to the string

puts:
    ; save register before will will modify them
    push si
    push ax

.loop:
    ; load the byte from ds:si
    lodsb
    


main:

    ; setup data segment
    mov ax,0
    mov ds, ax
    mov es, ax
    ; setup stack
    mov ss,ax
    mov sp,0x7C00


    hlt

.halt:
    jmp .halt

times 510-($-$$) db 0
dw 0xAA55