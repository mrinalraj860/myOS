org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A

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
    lodsb     ; load new char in al and increment si
    or al,al  ; check if al is 0
    jz .done  ; if al is 0, we are done
    
    mov ah,0x0E ; tty mode
    mov bh,0x00 
    int 0x10    ; call BIOS tty function
    jmp .loop

.done:
    ; restore registers
    pop ax
    pop si
    ret   ; transfer control back to the caller

main:

    ; setup data segment
    mov ax,0
    mov ds, ax
    mov es, ax
    ; setup stack
    mov ss,ax
    mov sp,0x7C00

    ; print message
    mov si, msg_hello
    call puts
    hlt

.halt:
    jmp .halt



msg_hello: db "Hello, World!",ENDL,0


times 510-($-$$) db 0
dw 0xAA55