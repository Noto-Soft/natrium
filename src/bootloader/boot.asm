use16
org 0x7c00

endl equ 0xd, 0xa

start:
    xor ax, ax
    mov ds, ax
    mov es, ax

    mov ax, 0x9000
    mov ss, ax
    mov sp, 0x0

    mov [drive], dl

    push es
    mov ah, 0x08
    int 0x13
    jc floppy_error
    pop es

    and cl, 0x3F
    xor ch, ch
    mov [sectors_per_track], cx
 
    inc dh
    mov byte [heads], dh
    mov byte [heads + 1], 0

    lea si, [yes]
    call puts

    mov ah, 0x86
    mov cx, 0xf
    mov dx, 0x4240
    int 0x15

main:
    mov ax, 1
    mov cl, 1
    mov dl, [drive]
    lea bx, [buffer]
    call read_blocks

    mov al, byte [buffer+16]
    cmp al, 0x1
    jne error_1

    mov ax, 2
    mov cl, 4
    mov dl, [drive]
    lea bx, [buffer]
    call read_blocks

    mov cl, byte [buffer]
    lea si, [kernel_sys]
    lea di, [buffer+32]
.find_kernel_loop:
    test cl, cl
    jz error_2
    dec cl
    lea si, [kernel_sys]
    push di
    push cx
    mov cx, 16
    repe cmpsb
    pop cx
    pop di
    pushf
    add di, 32
    popf
    jne .find_kernel_loop
    mov al, byte [di-32+19]
    test al, 0x80
    jnz .find_kernel_loop
    mov ax, word [di-32+16]
    mov cl, byte [di-32+18]
    mov dl, [drive]
    lea bx, [0x1000]
    mov es, bx
    xor bx, bx
    call read_blocks
    
    jmp 0x1000:0x0000

error_1:
    lea si, [error_wrong_filesystem]
    call puts
    jmp $

error_2:
    lea si, [error_kernel_not_found]
    call puts
    jmp $

puts:
    push ax
    push bx
    push si
    mov ah, 0xe
    xor bh, bh
    cld
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    pop si
    pop bx
    pop ax
    ret

strcmp:
    push si
    push di
.loop:
    mov al, [si]
    mov ah, [di]
    inc si
    inc di
    cmp al, ah
    jne .notequal
    test al, al
    jz .endofstring
    jmp .loop
.endofstring:
    xor ax, ax
    jmp .done
.notequal:
    mov ax, 1
    jmp .done
.done:
    pop di
    pop si
    ret

;
; Converts an LBA address to a CHS address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
;

lba_to_chs:

    push ax
    push dx

    ; dx = 0
    xor dx, dx
    ; ax = LBA / SectorsPerTrack
    div word [sectors_per_track]
                                        ; dx = LBA % SectorsPerTrack

    ; dx = (LBA % SectorsPerTrack + 1) = sector
    inc dx
    ; cx = sector
    mov cx, dx

    ; dx = 0
    xor dx, dx
    ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
    div word [heads]
                                        ; dx = (LBA / SectorsPerTrack) % Heads = head
    ; dh = head
    mov dh, dl
    ; ch = cylinder (lower 8 bits)
    mov ch, al
    push cx
    mov cl, 6
    shl ah, cl
    pop cx
    ; put upper 2 bits of cylinder in CL
    or cl, ah

    pop ax
    ; restore DL
    mov dl, al
    pop ax
    ret


;
; Reads sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
;
disk_read:

    ; save registers we will modify
    push ax
    push bx
    push cx
    push dx
    push di

    ; temporarily save CL (number of sectors to read)
    push cx
    ; compute CHS
    call lba_to_chs
    ; AL = number of sectors to read
    pop ax
    
    mov ah, 0x02
    ; retry count
    mov di, 3

.retry:
    ; save all registers, we don't know what bios modifies
    pusha ; macro
    ; set carry flag, some BIOS'es don't set it
    stc
    ; carry flag cleared = success
    int 0x13
    ; jump if carry not set
    jnc .done

    ; read failed
    popa ; macro
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:
    popa ; macro

    pop di
    pop dx
    pop cx
    pop bx
    ; restore registers modified
    pop ax
    ret


;
; Resets disk controller
; Parameters:
;   dl: drive number
;
disk_reset:
    pusha
    xor ah, ah
    stc
    int 0x13
    jc floppy_error
    popa
    ret

; ax - block number
; cl - amount of blocks
; dl - drive
; es:bx - address (you should always make sure the offset is aligned to 1kb if this will write over segment boundaries)
read_blocks:
    push ax
    push bx
    push cx
    push es
    shl ax, 1
.loop:
    test cl, cl
    jz .done
    dec cl
    push cx
    mov cl, 2
    call disk_read
    pop cx
    add ax, 2
    add bx, 1024
    test bx, bx
    jnz .loop
    push ax
    mov ax, es
    add ax, 0x1000
    mov es, ax
    pop ax
    jmp .loop
.done:
    pop es
    pop cx
    pop bx
    pop ax
    ret

floppy_error:
    jmp $

error_kernel_not_found db "File 'kernel.sys' missing", endl, 0
error_wrong_filesystem db "Incorrect fs version", endl, 0

kernel_sys db "kernel.sys      "

yes db "Lithium Bootloader 1.1", endl, 0

drive db ?
sectors_per_track dw ?
heads dw ?

db 510-($-$$) dup(0)
dw 0xaa55

label buffer 