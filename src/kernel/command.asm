org 0x0
use16

endl equ 0xa

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov [drive], dl

    xor ah, ah
    mov bl, 0x7
    lea si, [msg]
    int 0x21

    lea si, [directory_of_root]
    int 0x21

    mov ax, 2
    mov cl, 4
    mov dl, [drive]
    lea bx, [buffer]
    int 0x22

    call dir

    retf

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
    mov ah, 0x3
    int 0x21
    pop cx
    push si
    lea si, [str_directory]
    xor ah, ah
    int 0x21
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
    mov ah, 0x3
    int 0x21
    pop cx
    push si
    lea si, [str_file]
    xor ah, ah
    int 0x21
    pop si
.next_file:
    add si, 32
    loop .dir_loop_files
.done:
    popa
    ret

msg db endl, "an actual command.sys later...", endl, 0

directory_of_root db endl, "Directory of A:/", endl, " ", 0

str_file db "FILE", endl, " ", 0
str_directory db "DIRECTORY", endl, " ", 0

drive db ?

buffer rb 8192