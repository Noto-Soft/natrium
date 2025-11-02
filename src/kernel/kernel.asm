org 0x0
use16

endl equ 0xa

;
; Kernel
;

macro patch num, handler, rcs {
    mov word [es:num*4], handler
    mov word [es:num*4+2], rcs
}

main:
    mov ax, cs
    mov ds, ax
    mov es, ax

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

    mov bl, 0x7
    call clear_screen

    call enable_cursor

    mov ax, 0
    mov dl, [drive]
    lea si, [folder_natrium]
    call get_file
    test cl, cl
    jz .failure
    test ch, 0x80
    jz .failure

    jmp .start_reading_files
.failure:
    mov bl, 0x7
    lea si, [natrium]
    call puts

    jmp .patching
.start_reading_files:
    mov [folder_natrium_block], ax
    mov [folder_natrium_size], cl

    mov dl, [drive]
    lea si, [file_logo_txt]
    call get_file
    test cl, cl
    jz .failure
    test ch, 0x80
    jnz .failure

    lea bx, [0x2000]
    push es
    mov es, bx
    xor bx, bx
    call read_blocks
    pop es

    push ds
    mov bl, 0xe
    lea si, [0x2000]
    mov ds, si
    xor si, si
    call puts
    pop ds

    call clear_file_loading_space

    mov ax, [folder_natrium_block]
    mov cl, [folder_natrium_size]
    mov dl, [drive]
    lea si, [file_boot_txt]
    call get_file
    test cl, cl
    jz .failure
    test ch, 0x80
    jnz .failure

    lea bx, [0x2000]
    push es
    mov es, bx
    xor bx, bx
    call read_blocks
    pop es

    push ds
    mov bl, 0x7
    lea si, [0x2000]
    mov ds, si
    xor si, si
    call puts
    pop ds
.patching:
    push es
    xor ax, ax
    mov es, ax
    mov ax, cs
    patch 0x21, int21, ax
    patch 0x22, int22, ax
    patch 0x23, int23, ax
    pop es

    mov bl, 0x7
    lea si, [directory_of_root]
    call puts

    mov ax, 2
    mov cl, 4
    mov dl, [drive]
    lea bx, [buffer]
    call read_blocks

    call dir

    mov al, 0xa
    call putc

    mov bl, 0x7
    lea si, [directory_of_natrium]
    call puts

    mov ax, [folder_natrium_block]
    mov cl, [folder_natrium_size]
    mov dl, [drive]
    lea bx, [buffer]
    call read_blocks

    call dir
halt:
    cli
    hlt

dir:
    pusha
    mov bl, 0x7
    xor cx, cx
    mov cl, byte [buffer]
    lea si, [buffer+32]
.dir_loop_dirs:
    mov al, [si]
    test al, al
    jz .loop_files
    mov al, [si+19]
    test al, 0x80
    jz .next_dir
    push cx
    mov cx, 16
    call puts_length
    pop cx
    push si
    lea si, [str_directory]
    call puts
    pop si
.next_dir:
    add si, 32
    loop .dir_loop_dirs
.loop_files:
    xor cx, cx
    mov cl, byte [buffer]
    lea si, [buffer+32]
.dir_loop_files:
    mov al, [si]
    test al, al
    jz .done
    mov al, [si+19]
    test al, 0x80
    jnz .next_file
    push cx
    mov cx, 16
    call puts_length
    pop cx
    push si
    lea si, [str_file]
    call puts
    pop si
.next_file:
    add si, 32
    loop .dir_loop_files
.done:
    popa
    ret

clear_file_loading_space:
    push ax
    push cx
    push di
    push es

    mov ax, 0x2000
    mov es, ax
    xor di, di
    xor ax, ax
    mov cx, 0x8000
    cld
    rep stosw

    pop es
    pop di
    pop cx
    pop ax
    ret

nothing:
    ret

int21:
    push si
    push ax
    mov al, ah
    xor ah, ah
    mov si, ax
    pop ax
    shl si, 1
    push ax
    mov ax, [cs:.call_table+si]
    mov [cs:call_value], ax
    pop ax
    pop si
    call word [cs:call_value]
    iret
.call_table:
    dw puts, putc, poke_char, set_cursor_position, get_cursor_position, set_cursor_shape, enable_cursor, disable_cursor, clear_screen, scroll_screen
    dw (256-($-.call_table))/2 dup(nothing)

int22:
    call read_blocks
    iret

int23:
    call get_file
    iret

enable_cursor:
    push ax
    push cx
    mov ah, 0x1
    mov cx, [cs:cursor_shape]
    int 0x10
    pop cx
    pop ax
    ret

disable_cursor:
    push ax
    push cx
    mov ah, 0x1
    mov cx, 0x2607
    int 0x10
    pop cx
    pop ax
    ret

set_cursor_shape:
    push ax
    mov ah, 0x1
    int 0x10
    mov [cs:cursor_shape], cx
    pop ax
    ret

set_cursor_position:
    push ax
    push bx
    push dx
    mov ah, 0x2
    xor bh, bh
    mov dx, cx
    int 0x10
    mov [cs:cursor_position], cx
    pop dx
    pop bx
    pop ax
    ret

get_cursor_position:
    mov cx, [cs:cursor_position]
    ret

update_cursor_position:
    push ax
    push bx
    push dx
    mov ah, 0x2
    xor bh, bh
    mov dx, [cs:cursor_position]
    int 0x10
    pop dx
    pop bx
    pop ax
    ret

; in:
;   cx - cursor
; out:
;   di - offset
cursor_memory_offset:
    push ax
    push bx
    push cx
    push dx
    xor ah, ah
    mov al, ch
    mov bx, 80
    mul bx
    xor ch, ch
    add ax, cx
    shl ax, 1
    mov di, ax
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; al - char
; bl - formatting byte
; cx - cursor
poke_char:
    push ax
    push es
    mov ah, bl
    push ax
    mov ax, 0xb800
    mov es, ax
    pop ax
    push di
    call cursor_memory_offset
    mov [es:di], ax
    pop di
    pop es
    pop ax
    ret

; al - char
; bl - formatting byte
put_char:
    push ax
    push cx
    push es
    cmp al, 0xa
    je .newline
    cmp al, 0x20
    je .space
    mov ah, bl
    push ax
    mov ax, 0xb800
    mov es, ax
    pop ax
    push di
    mov cx, [cs:cursor_position]
    call cursor_memory_offset
    mov [es:di], ax
    pop di
    inc cl
.check_cursor_stuff:
    cmp cl, 80
    jnae .c1
    xor cl, cl
    inc ch
.check_cursor_stuff2:
    cmp ch, 25
    jnae .c1
    call scroll_screen
.c1:
    mov [cs:cursor_position], cx
    pop es
    pop cx
    pop ax
    ret
.newline:
    mov ch, byte [cs:cursor_position+1]
    inc ch
    xor cl, cl
    jmp .check_cursor_stuff2
.space:
    mov cx, [cs:cursor_position]
    inc cl
    jmp .check_cursor_stuff

putc:
    call put_char
    call update_cursor_position
    ret

puts:
    push ax
    push si
    cld
.loop:
    lodsb
    test al, al
    jz .done
    call put_char
    jmp .loop
.done:
    call update_cursor_position
    pop si
    pop ax
    ret

puts_length:
    push ax
    push cx
    push si
    cld
.loop:
    lodsb
    call put_char
    loop .loop
.done:
    call update_cursor_position
    pop si
    pop cx
    pop ax
    ret

; bl - formatting byte
clear_screen:
    push ax
    push cx
    push di
    push es

    cld

    mov ax, 0xb800
    mov es, ax

    xor di, di
    mov cx, 80*26 ; clear an extra row for scrolling purposes
    mov ah, bl
    mov al, 0x20
    rep stosw

    pop es
    pop di
    pop cx
    pop ax
    ret

scroll_screen:
    push ax
    push cx
    push si
    push di
    push ds
    push es

    cld

    mov ax, 0xb800
    mov ds, ax
    mov es, ax

    mov si, 160
    xor di, di
    mov cx, 80*25
    rep movsw

    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret

lba_to_chs:
    push ax
    push dx

    xor dx, dx
    div word [cs:sectors_per_track]

    inc dx
    mov cx, dx

    xor dx, dx
    div word [cs:heads]

    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah
    pop ax
    mov dl, al
    pop ax
    ret

disk_read:
    push ax
    push bx
    push cx
    push dx
    push disk_read

    push cx
    call lba_to_chs
    pop ax

    mov ah, 0x2
    mov di, 3
.retry:
    pusha
    stc
    int 13h
    jnc .done

    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry
.fail:
    jmp floppy_error
.done:
    popa
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

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
; es:bx - address
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

; ax - starting block of directory (will read from root directory if 0)
; cl - size of directory in blocks (doesn't matter if ax is 0)
; dl - drive
; ds:si - filename
; returns: 
;   ax - starting block (0 if nonexistant)
;   ch - attribute byte
;   cl - blocks size (0 if nonexistant)
get_file:
    push di
    push es
    push bx

    push ax

    mov ax, cs
    mov es, ax

    mov ax, 1
    mov cl, 1
    lea bx, [buffer]
    call read_blocks

    mov al, byte [cs:buffer+16]
    cmp al, 0x1
    jne error_1

    pop ax

    cmp ax, 0
    je .read_root

    cmp cl, 8
    jng .read_directory
    mov cl, 8
.read_directory:
    lea bx, [buffer]
    call read_blocks

    jmp .init_loop
.read_root:
    mov ax, 2
    mov cl, 4
    lea bx, [buffer]
    call read_blocks
.init_loop:
    mov cl, byte [cs:buffer]
    lea di, [buffer+32]
.find_kernel_loop:
    test cl, cl
    jz .missing

    dec cl

    push si
    push di
    push cx
    mov cx, 16
    repe cmpsb
    pop cx
    pop di
    pop si

    pushf
    add di, 32
    popf

    jne .find_kernel_loop
    mov ch, byte [cs:di-32+19]

    mov ax, word [cs:di-32+16]
    mov cl, byte [cs:di-32+18]

    pop bx
    pop es
    pop di
    ret
.missing:
    pop bx
    pop es
    pop di
    pop cx
    pop bx
    xor ax, ax
    xor cl, cl
    ret

error_1:
    mov ax, cs
    mov ds, ax
    mov bl, 0x7
    lea si, [error_wrong_filesystem]
    call puts
    jmp $

error_kernel_not_found db "File missing", endl, 0
error_wrong_filesystem db "Incorrect fs version", endl, 0

cursor_shape dw 0x003f
cursor_position dw 0

natrium db "Natrium", endl, endl, "'boot.txt' missing...", endl, 0

directory_of_root db "Directory of A:/", endl, 0
directory_of_natrium db "Directory of A:/natrium/", endl, 0

str_file db "FILE", endl, 0
str_directory db "DIRECTORY", endl, 0

folder_natrium db "natrium         "
file_logo_txt db "logo.txt        "
file_boot_txt db "boot.txt        "

drive db ?
sectors_per_track dw ?
heads dw ?

call_value dw ?

folder_natrium_block dw ?
folder_natrium_size db ?

buffer rb 8192