org 0x0
use16

endl equ 0xa

start:
    mov ax, cs
    mov ds, ax

    mov [drive], dl

    test si, si
    jz read_image

    clc
    lea di, [image_name]
    mov cx, 16
.image_name_load_loop:
    mov al, [es:si]
    inc si
    jc .set_space
    test al, al
    jz .set_space
    mov [di], al
    inc di
    loop .image_name_load_loop
    jmp read_image
.set_space:
    mov byte [di], " "
    inc di
    loop .image_name_load_loop

read_image:
    mov ax, cs
    mov ds, ax

    mov ax, 0
    mov dl, [drive]
    lea si, [image_name]
    int 0x24
    test cl, cl
    jz fail_not_exist
    test ch, 0x80
    jnz fail_not_file

    lea bx, [0x4000]
    mov ds, bx
    mov es, bx
    xor bx, bx
    int 0x22

parse_header:
    mov ax, [0x0]
    cmp ax, "Bm"
    jne fail_not_nsbmp2

    mov al, [0x2]
    mov [cs:bitmap_type], al
    lea si, [0x7]
    cmp al, "V"
    je draw_bmp
    mov dx, 256
    cmp al, "C"
    je set_palletes
    mov dx, 16
    cmp al, "R"
    je set_palletes
    mov dx, 4
    cmp al, "T"
    je set_palletes
    mov dx, 2
    cmp al, "M"
    je set_palletes
    jmp fail_not_valid

set_palletes:
    mov ax, 0x13
    int 0x10
    
    xor al, al
.loop:
    mov bx, [si]
    mov cl, [si+2]
    call set_pallete
    add si, 3
    inc al
    dec dx
    cmp dx, 0
    ja .loop

draw_bmp:
    mov al, [cs:bitmap_type]
    cmp al, "V"
    je draw_8bpp
    cmp al, "C"
    je draw_8bpp
    cmp al, "R"
    je draw_4bpp
    cmp al, "T"
    je draw_2bpp

draw_1bpp:
    call draw_fullscreen_mono_bmp
    xor ah, ah
    int 0x16
    jmp exit

draw_2bpp:
    call draw_fullscreen_2bpp_bmp
    xor ah, ah
    int 0x16
    jmp exit

draw_4bpp:
    call draw_fullscreen_4bpp_bmp
    xor ah, ah
    int 0x16
    jmp exit

draw_8bpp:
    call draw_fullscreen_bmp
    xor ah, ah
    int 0x16
    ; jmp exit

exit:
    call reset_vga
    retf

fail_not_nsbmp2:
    mov ax, cs
    mov ds, ax
    xor ah, ah
    mov bl, 0x4
    lea si, [error_not_nsbmp2]
    int 0x21
    retf

fail_not_valid:
    mov ax, cs
    mov ds, ax
    xor ah, ah
    mov bl, 0x4
    lea si, [error_not_valid]
    int 0x21
    retf

fail_not_exist:
    mov ax, cs
    mov ds, ax
    xor ah, ah
    mov bl, 0x4
    lea si, [error_not_exist]
    int 0x21
    retf

fail_not_file:
    mov ax, cs
    mov ds, ax
    xor ah, ah
    mov bl, 0x4
    lea si, [error_not_file]
    int 0x21
    retf

; al - pallete to set
; bl, bh, cl: rgb
set_pallete:
    push ax
    push dx
    mov dx, 0x3c8
    out dx, al

    inc dx
    mov al, bl
    out dx, al
    mov al, bh
    out dx, al
    mov al, cl
    out dx, al
    pop dx
    pop ax
    ret

; ds:si - bitmap data
draw_fullscreen_bmp:
    push ax
    push bx
    push cx

    xor ebx, ebx
    mov cx, 320*200
.loop:
    mov al, [si+bx]
    mov [fs:0xa0000+ebx], al
    inc bx
    cmp bx, cx
    jb .loop

    pop cx
    pop bx
    pop ax
    ret

; ds:si - bitmap data
draw_fullscreen_4bpp_bmp:
    push ax
    push bx
    push cx
    push ebp

    xor bx, bx
    xor ebp, ebp
    mov cx, 320*(200/2)
.loop:
    mov al, [si+bx]
    push ax
    shr al, 4
    mov [fs:0xa0000+ebp], al
    pop ax
    and al, 0xf
    inc bp
    mov [fs:0xa0000+ebp], al
    inc bx
    inc ebp
    cmp bx, cx
    jb .loop

    pop ebp
    pop cx
    pop bx
    pop ax
    ret	

; ds:si - bitmap data
draw_fullscreen_2bpp_bmp:
    push ax
    push bx
    push cx
    push ebp

    xor bx, bx
    xor ebp, ebp
    mov cx, 320*(200/4)
.loop:
    mov al, [si+bx]
rept 4 {
    push ax
    rol al, 2
    and al, 0x3
    mov [fs:0xa0000+ebp], al
    pop ax
    shl al, 2
    inc ebp
}
	inc bx
    cmp bx, cx
    jb .loop

    pop ebp
    pop cx
    pop bx
    pop ax
    ret	

; ds:si - bitmap data
draw_fullscreen_mono_bmp:
    push ax
    push bx
    push cx
    push ebp

    xor bx, bx
    xor ebp, ebp
    mov cx, 320*(200/8)
.loop:
    mov al, [si+bx]
rept 8 {
    push ax
    rol al, 1
    and al, 0x1
    mov [fs:0xa0000+ebp], al
    pop ax
    shl al, 1
    inc ebp
}
    inc bx
    cmp bx, cx
    jb .loop

    pop ebp
    pop cx
    pop bx
    pop ax
    ret	

reset_vga:
    mov ax, 0x3
    int 0x10

    mov ah, 0xa
    mov bl, 0x7
    int 0x21

    mov ah, 0x5
    xor cx, cx
    int 0x21

    ret

error_not_nsbmp2 db "File specified is not NSBMP 2.0 format.", endl, 0
error_not_valid db "Bitmap specified does not have a supported format.", endl, 0
error_not_exist db "File specified does not exist", endl, 0
error_not_file db "File specified is a directory!", endl, 0

image_name db "bliss.bmp       "

drive db ?
directory_block dw ?
directory_size db ?
bitmap_type db ?