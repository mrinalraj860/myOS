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

    mov ax,0
    mov ds, ax
    mov es, ax
    ; setup stack
    mov ss,ax
    mov sp,0x7C00
    ; some BIOS functions will start us at 07C0:0000 than 0000:7C00
    push es
    push word .after
    retf
.after:

    mov [ebr_drive_number], dl
    ; show loading message
    mov si, msg_loading
    call puts

    ; read drive parameters
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F ; clear the high 2 bits of cl
    xor ch,ch
    mov [bdb_sector_per_track], cx

    inc dh
    mov [bdb_heads], dh

    mov ax, [bdb_sector_per_fat]    ; read the first sector of the FAT
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx
    add ax, [bdb_reserved_sectors]
    push ax

    mov ax, [bdb_sector_per_fat]
    shl ax,5
    xor dx, dx
    div word [bdb_bytes_per_sector]

    test dx,dx
    jz .root_dir_after
    inc ax

.root_dir_after:

    mov cl,al
    pop ax
    mov dl, [ebr_drive_number]
    mov bx, buffer
    call disk_read

    ;search for kernal . bin file 
    xor bx, bx
    mov di, buffer

.search_kernal:

    mov si, file_kernal_bin  ; storing file name in si register 

    mov cx,11   ; stroring length of kernal . bin file name in cx register
    push di
    repe cmpsb ; compare string bytes
    pop di
    je .found_kernal

    add di,32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_kernal

    jmp kernal_not_found_error

.found_kernal:

    ; di should have same value as the start of the file entry

    mov ax, [di+26] ; cluster number
    mov [kernal_cluster], ax
    ; read FAT from disk to the memory
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sector_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read


    ; read kernal and process FAT chain since we are in 16 bit mode we cant write memory above 1 MB
    mov bx, KERNAL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNAL_LOAD_OFFSET

.loop_kernal_loop:
    ; read next cluster
    mov ax, [kernal_cluster]
    ; not nice hardcoding 512 bytes per sector
    add ax, 31  ; first cluster = (kernal_cluster - 2 )* sectors per cluster + data start

    mov cl,1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector] ; overflow is kernal file is more than 512

    ; compute next cluster
    mov ax, [kernal_cluster]
    mov cx,3
    mul cx
    mov cx,2
    div cx

    mov si, buffer
    add si,ax
    mov ax, [ds:si]

    or dx,dx
    jz .even
 .odd:
    shr ax,4
    jmp .next_cluster_after

 .even:
    add ax, 0x0FFF

 .next_cluster_after:
    cmp ax, 0xFF8
    jae .read_finish

    mov [kernal_cluster], ax
    jmp .loop_kernal_loop

.read_finish:
    ; jump to kernal
    mov dl, [ebr_drive_number]
    mov ax, KERNAL_LOAD_SEGMENT
    mov ds,ax
    mov es,ax
    jmp KERNAL_LOAD_SEGMENT:KERNAL_LOAD_OFFSET

    jmp wait_key_and_reboot
    cli ; disable interrupts as if mouse will also cause interupts
    hlt


;
; Error handling
;

floppy_error:
    mov si, msg_error_failed_to_read
    call puts
    jmp wait_key_and_reboot

kernal_not_found_error:
    mov si, msg_error_kernal_not_found
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



puts:
    ; save registers we will modify
    push si
    push ax
    push bx

.loop:
    lodsb               ; loads next character in al
    or al, al           ; verify if next character is null?
    jz .done

    mov ah, 0x0E        ; call bios interrupt
    mov bh, 0           ; set page number to 0
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si    
    ret




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




msg_loading: db "Loading...",ENDL,0
msg_error_failed_to_read: db "Failed to read disk",ENDL,0
msg_error_kernal_not_found: db "KERNAL.BIN file not found",ENDL,0
file_kernal_bin: db "KERNAL  BIN"
kernal_cluster: dw 0

test: db 11h, 22h,33h

KERNAL_LOAD_SEGMENT: equ 0x2000
KERNAL_LOAD_OFFSET: equ 0

times 510-($-$$) db 0
dw 0xAA55

buffer: