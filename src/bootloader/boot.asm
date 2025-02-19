org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A



;
; Fat12 header
;
jmp short start
nop

bdb_oem:    db 'MSWIN4.1'
bdb_bytes_per_sector:   dw 512  ; 0200
bdb_sector_per_cluster: db 1     
bdb_reserved_sectors:   dw 1
bdb_fat_count:  db 2
bdb_dir_entries_count:  dw 0E0h
bdb_total_sectors:  dw 2880
bdb_media_descriptor_type:   db 0F0h
bdb_sector_per_fat: dw 9
bdb_sector_per_track:   dw 18
bdb_heads:  dw 2
bdb_hidden_sectors: dd 0
bdb_large_sector_count: dd 0

; extenderd boot record
ebr_drive_number:   db 0
ebr_reserved:   db 0
ebr_signature:  db 29h
ebr_volume_id:  db 12h, 34h, 56h, 78h 
ebr_volume_label:   db 'Mrinal Raj ' ;Should be 11 Bytes
ebr_system_id:  db 'FAT12   ' ;Should be 8 Bytes













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


    ; read something from disk
    mov ax,1
    mov cl,1     
    mov bx, 0x7E00
    call disk_read



    ; print message
    mov si, msg_hello
    call puts
    cli ; disable interrupts as if mouse will also cause interupts
    hlt


;
; Error handling
;

floppy_error:
    mov si, msg_error_failed_to_read
    call puts
    jmp wait_key_and_reboot


wait_key_and_reboot:
    mov ah, 0
    int 16h
    jmp 0FFFFh:0 ; reboot Jump to begning of BIOS

    htl



.halt:
    cli ; disable interrupts
    hlt







;
; Disk routines sector, head, cylinder
;

;
; Convert LBA(logical Block address)
; Params:
;   - ax: LBA
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder number
;   - dh: head number
;

lba_to_chs:
    push ax
    push dx

    xor dx, dx ; dx = 0
    div word [bdb_sector_per_track] ; divide by sector per track ax = LBA/sector per track word  = dx:ax
                                    ; dx = LBA % sector per track
    
    inc dx ; dx = head
    mov cx, dx ; cx = sector

    xor dx, dx ; dx = 0
    div word [bdb_heads] ; divide by heads ax = LBA/heads word  = dx:ax
                                    ; dx = LBA % heads
    mov dh, dl ; dh = head 
    mov ch, al ; ch = cylinder
    shl ah, 6 ; ah = cylinder high
    or ch, ah ; ch = cylinder high + cylinder low

    pop ax
    mov dl,al  ; restore dl
    pop ax
    ret



;
; Read a sector from disk
; Params:
;   - ax: LBA address
;   - cl: number of sectors to read
;   - dl: drive number
;   -es:bx: memory adress where to store read data
;

disk_read:
    push ax
    push bx
    push cx
    push dx
    push di


    push cx ; save cx
    call lba_to_chs
    pop ax

    mov ah, 02h ; read sector
    mov di, 3

.retry:
    pusha
    stc
    int 13h
    jnc .done  ; if no error, we are done

    ;read failed retry
    popa
    call disk_read

    dec di
    test di, di

    jnz .retry

.fail:
    ;all attempts failed
    jmp floppy_error

.done:
    popa
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret


;
; reset Disk
; 
disk_reset:
    pusha
    mov ah,0
    stc
    int 13h
    jc floppy_error
    popa
    ret




msg_hello: db "Hello, World!",ENDL,0
msg_error_failed_to_read: db "Failed to read disk",ENDL,0

times 510-($-$$) db 0
dw 0xAA55