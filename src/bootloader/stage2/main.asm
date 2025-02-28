org 0x0
bits 16


%define ENDL 0x0D, 0x0A

start:
    mov si, msg_hello
    call puts
.halt:
    cli
    hlt

;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
puts:
    ; save register before will will modify them
    push si
    push ax
    push bx

.loop:
    ; load the byte from ds:si
    lodsb     ; load new char in al and increment si
    or al,al  ; check if al is 0
    jz .done  ; if al is 0, we are done
    
    mov ah,0x0E ; tty mode
    mov bh,0 
    int 0x10    ; call BIOS tty function
    jmp .loop

.done:
    ; restore registers
    pop bx
    pop ax
    pop si

    ret   ; transfer control back to the caller






msg_hello: db "Hello, World from Kernal!",ENDL,0