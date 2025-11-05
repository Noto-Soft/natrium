org 0x0
use16

endl equ 0xa

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov [drive], dl

    mov [directory_block], 0

main:
    xor ah, ah
    mov bl, 0x7
    lea si, [msg]
    int 0x21

    lea si, [directory_of_root]
    int 0x21

    call dir

    lea si, [directory_of_system]
    int 0x21

    xor ax, ax
    mov dl, [drive]
    lea si, [folder_system]
    int 0x24
    test cl, cl
    jz exit
    test ch, 0x80
    jz exit

    mov [directory_block], ax
    mov [directory_size], cl

    call dir

exit:
    retf

read_directory:
    pusha
    mov ax, [directory_block]
    test ax, ax
    jnz .specified
    mov ax, 2
    mov cl, 4
    jmp .read
.specified:
    mov cl, [directory_size]
    test cl, cl
    jnz .size_check
    mov cl, 1
    jmp .read
.size_check:
    cmp cl, 8
    jna .entries_check
    mov cl, 8
.entries_check:
    mov dl, [buffer]
    test dl, dl
    jnz .read
    mov byte [buffer], 255
.read:
    mov dl, [drive]
    lea bx, [buffer]
    int 0x22
    popa
    ret

dir:
    call read_directory
    pusha
    mov bl, 0x7
    xor cx, cx
    mov cl, byte [buffer]
    lea si, [buffer+32]
.dir_loop_dirs:
    mov al, [si]
    test al, al
    jz .loop_sys_files
    mov al, [si+19]
    test al, 0x80
    jz .next_dir
    test al, 0x01
    jnz .next_dir
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
.loop_sys_files:
    xor cx, cx
    mov cl, byte [buffer]
    lea si, [buffer+32]
.dir_loop_sys_files:
    mov al, [si]
    test al, al
    jz .loop_files
    mov al, [si+19]
    test al, 0x80
    jnz .next_sys_file
    test al, 0x01
    jz .next_sys_file
    push cx
    mov cx, 16
    mov ah, 0x3
    int 0x21
    pop cx
    push si
    lea si, [str_system]
    xor ah, ah
    int 0x21
    pop si
.next_sys_file:
    add si, 32
    loop .dir_loop_sys_files
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
    test al, 0x01
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
directory_of_system db endl, "Directory of A:/System/", endl, " ", 0

str_file db "FILE", endl, " ", 0
str_system db "SYSTEM FILE", endl, " ", 0
str_directory db "DIRECTORY", endl, " ", 0

folder_system db "System          "

drive db ?

directory_block dw ?
directory_size db ? 

buffer rb 8192