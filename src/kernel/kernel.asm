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

    xor ax, ax
    mov dl, [drive]
    lea si, [folder_system]
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

    jmp $
.start_reading_files:
    mov [folder_system_block], ax
    mov [folder_system_size], cl

    mov dl, [drive]
    lea si, [file_logo_txt]
    call get_file
    test cl, cl
    jz .failure
    test ch, 0x80
    jnz .failure

    push es
    lea bx, [0x4000]
    mov es, bx
    xor bx, bx
    call read_blocks
    pop es

    push ds
    mov bl, 0x2
    lea si, [0x4000]
    mov ds, si
    xor si, si
    call puts
    pop ds

    call clear_file_loading_space

    mov ax, [folder_system_block]
    mov cl, [folder_system_size]
    mov dl, [drive]
    lea si, [file_boot_txt]
    call get_file
    test cl, cl
    jz .failure
    test ch, 0x80
    jnz .failure

    push es
    lea bx, [0x4000]
    mov es, bx
    xor bx, bx
    call read_blocks
    pop es

    push ds
    mov bl, 0x7
    lea si, [0x4000]
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
    patch 0x24, int24, ax
    pop es

    mov ax, [folder_system_block]
    mov cl, [folder_system_size]
    mov dl, [drive]
    lea si, [file_unreal_sys]
    call get_file
    test cl, cl
    jz .failure
    test ch, 0x80
    jnz .failure

    push ds
    push es
    lea bx, [0x2000]
    mov es, bx
    xor bx, bx
    call read_blocks
    push cs
    push word .return_point_unreal_sys
    push es
    push bx
    xor bp, bp
    xor si, si
    retf
.return_point_unreal_sys:
    pop es
    pop ds
    
    mov ax, [folder_system_block]
    mov cl, [folder_system_size]
    mov dl, [drive]
    lea si, [file_command_sys]
    call get_file
    test cl, cl
    jz .failure
    test ch, 0x80
    jnz .failure

    push ds
    push es
    lea bx, [0x2000]
    mov es, bx
    xor bx, bx
    call read_blocks
    push cs
    push word .return_point_command_sys
    push es
    push bx
    xor bp, bp
    xor si, si
    retf
.return_point_command_sys:
    pop es
    pop ds
halt:
    cli
    hlt

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

stub:
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
    dw puts, putc, poke_char, puts_length, putd, \
        set_cursor_position, get_cursor_position, set_cursor_shape, enable_cursor, disable_cursor, \
        clear_screen, scroll_screen, \
        putc_escaped, putdd, newline
    dw (256-($-.call_table))/2 dup(stub)

int22:
    call read_blocks
    iret

int23:
    call write_blocks
    iret

int24:
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
; carry flag - character is escaped? (flag is preserved throughout calls)
put_char:
    push ax
    push cx
    push es
    pushf
    jc .ignore_escaped_character
    cmp al, endl
    je .newline
    cmp al, 0xd
    je .carriage_return
    cmp al, 0x20
    je .space
    cmp al, 0x8
    je .backspace
.ignore_escaped_character:
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
    dec ch
.c1:
    mov [cs:cursor_position], cx
.c2:
    popf
    pop es
    pop cx
    pop ax
    ret
.newline:
    mov cx, [cs:cursor_position]
    inc ch
    xor cl, cl
    jmp .check_cursor_stuff2
.carriage_return:
    mov cx, [cs:cursor_position]
    xor cl, cl
    jmp .check_cursor_stuff
.space:
    mov cx, [cs:cursor_position]
    inc cl
    jmp .check_cursor_stuff
.backspace:
    mov cx, [cs:cursor_position]
    test cl, cl
    jz .c2
    dec cl
    jmp .c1

; al - char
; bl - formatting
putc:
    pushf
    clc
    call put_char
    call update_cursor_position
    popf
    ret

putc_escaped:
    pushf
    stc
    call put_char
    call update_cursor_position
    popf
    ret

puts:
    push ax
    push si
    pushf
    clc
    cld
.loop:
    lodsb
    test al, al
    jz .done
    cmp al, 0x1
    je .escape
    call put_char
    jmp .loop
.escape:
    lodsb
    stc
    call put_char
    clc
    jmp .loop
.done:
    call update_cursor_position
    popf
    pop si
    pop ax
    ret

puts_length:
    push ax
    push cx
    push si
    pushf
    clc
    cld
.loop:
    lodsb
    cmp al, 0x1
    je .escape
    call put_char
    loop .loop
    jmp .done
.escape:
    cmp cx, 1
    je .done
    lodsb
    stc
    call put_char
    clc
    add cx, 1
    loop .loop
.done:
    call update_cursor_position
    popf
    pop si
    pop cx
    pop ax
    ret

putd:
    push ax
    push bx
    push dx
    push si

    xor si, si

    test cx, cx
    jnz .convert

    mov al, '0'
    call putc
    jmp .done
.convert:
    mov ax, cx
.next_digit:
    xor dx, dx
    push bx
    mov bx, 10
    div bx
    pop bx
    push dx
    inc si
    test ax, ax
    jnz .next_digit
.print_digits:
    pop dx
    add dl, '0'
    mov al, dl
    call putc
    dec si
    jnz .print_digits
.done:
    pop si
    pop dx
    pop bx
    pop ax
    ret

putdd:
    push eax
    push ebx
    push edx
    push si

    xor si, si

    test ecx, ecx
    jnz .convert

    mov al, '0'
    call putc
    jmp .done
.convert:
    mov eax, ecx
.next_digit:
    xor edx, edx
    push ebx
    mov ebx, 10
    div ebx
    pop ebx
    push edx
    inc esi
    test eax, eax
    jnz .next_digit
.print_digits:
    pop edx
    add dl, '0'
    mov al, dl
    call putc
    dec esi
    jnz .print_digits
.done:
    pop si
    pop edx
    pop ebx
    pop eax
    ret

newline:
    push ax
    pushf
    clc
    mov al, endl
    call put_char
    popf
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

disk_write:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax
    
    mov ah, 0x3
    mov di, 3
.retry:
    pusha
    stc
    int 0x13
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

; ax - block number
; cl - amount of blocks
; dl - drive
; es:bx - address (you should always make sure the offset is aligned to 1kb if this will read over segment boundaries)
write_blocks:
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
    call disk_write
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
    mov ax, cs
    mov ds, ax
    mov bl, 0x7
    lea si, [error_floppy]
    call puts
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
    jne bad_fs

    pop ax

    test ax, ax
    jz .read_root

    cmp cl, 8
    jna .read_directory
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
    xor ax, ax
    xor cl, cl
    ret

bad_fs:
    mov ax, cs
    mov ds, ax
    mov bl, 0x7
    lea si, [error_wrong_filesystem]
    call puts
    jmp $

error_kernel_not_found db "File missing", endl, 0
error_wrong_filesystem db "Incorrect fs version", endl, 0
error_floppy db "Floppy error", endl, 0

cursor_shape dw 0x003f
cursor_position dw 0

natrium db "Natrium", endl, endl, "Critical files missing...", endl, 0

align 16

folder_system db "System          "
file_logo_txt db "logo.txt        "
file_boot_txt db "boot.txt        "
file_command_sys db "command.sys     "
file_unreal_sys db "unreal.sys      "

drive db ?
sectors_per_track dw ?
heads dw ?

call_value dw ?

folder_system_block dw ?
folder_system_size db ?

buffer rb 8192