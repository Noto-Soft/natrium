org 0x0
use16

start:
    mov ax, cs
    mov ds, ax
    xor ax, ax
    mov es, ax

    mov cx, code_length
    lea si, [code_start]
    lea di, [0x500]
    rep movsb

    jmp 0x0000:0x0500

code_start:
    xor ax, ax
    mov ds, ax

unreal_init:
    cli
    push fs

    lgdt [0x500+(gdtinfo-code_start)]

    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x8:(0x500+(.pmode-code_start))
.pmode:
    mov bx, 0x10
    mov fs, bx

    and eax, not 1
    mov cr0, eax
    jmp 0x0:(0x500+(.unreal-code_start))
.unreal:
    pop fs
    sti

    ; a20 line
    in al, 0x92
    or al, 2
    out 0x92, al

    retf

gdtinfo:
   dw gdt_end - gdt - 1   ;last byte in table
   dd 0x500+(gdt-code_start)                 ;start of table

gdt:        dd 0,0        ; entry 0 is always unused
codedesc:   db 0xff, 0xff, 0, 0, 0, 10011010b, 00000000b, 0
flatdesc:   db 0xff, 0xff, 0, 0, 0, 10010010b, 11001111b, 0
gdt_end:

code_length = $ - code_start