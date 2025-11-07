org 0x0
use16

endl equ 0xa

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov [drive], dl

    mov [directory_block], 0

    mov ah, 0x1
    mov al, 0xa
    mov bl, 0x7
    int 0x21

prompt:
    xor ax, ax
    mov cx, 16
    lea di, [input_buffer]
    rep stosw

    call prompt_message
    lea di, [input_buffer]
    mov byte [di], 0
.loop:
    xor ah, ah
    int 0x16
    cmp al, 0xd
    je parse_prompt
    cmp al, 0x8
    je .backspace
    cmp di, input_buffer+MAX_INPUT_SIZE
    je .loop
    mov ah, 0x1
    int 0x21
    mov [di], al
    mov byte [di+1], 0
    inc di
    jmp .loop
.backspace:
    cmp di, input_buffer
    je .loop
    dec di
    mov byte [di], 0
    mov ah, 0x1
    int 0x21
    mov al, 0xff
    int 0x21
    mov al, 0x8
    int 0x21
    jmp .loop

parse_prompt:
    mov ah, 0x1
    mov al, 0xa
    mov bl, 0x7
    int 0x21

    mov al, [input_buffer]
    test al, al
    jz prompt

.check_dir:
    lea si, [str_dir]
    lea di, [input_buffer]
    mov cx, 3
    repe cmpsb
    jne .not_dir
    mov al, [di]
    cmp al, 0x20
    je .dir
    test al, al
    jz .dir
    jmp .not_dir
.dir:
    xor ah, ah
    lea si, [directory_of]
    int 0x21

    call cwd_message

    mov ah, 0x1
    mov al, 0xa
    int 0x21
    mov al, " "
    int 0x21

    call dir

    mov al, 0xd
    int 0x21

    jmp prompt
.not_dir:
.check_cd:
    lea si, [str_cd]
    lea di, [input_buffer]
    mov cx, 2
    repe cmpsb
    jne .not_cd
.maybe_cd:
    call parse_cd
    cmp ax, 1
    je .not_cd
    jmp prompt
.not_cd:
.check_cls:
    lea si, [str_cls]
    lea di, [input_buffer]
    mov cx, 3
    repe cmpsb
    jne .not_cls
    mov al, [input_buffer+3]
    test al, al
    jz .cls
    cmp al, " "
    je .cls
    jmp .not_cls
.cls:
    mov ah, 0xa
    int 0x21
    mov ah, 0x5
    xor cx, cx
    int 0x21
    jmp prompt
.not_cls:
.check_help:
    lea si, [str_help]
    lea di, [input_buffer]
    mov cx, 4
    repe cmpsb
    jne .not_help
    mov al, [input_buffer+4]
    test al, al
    jz .help
    cmp al, " "
    je .help
    jmp .not_help
.help:
    xor ah, ah
    lea si, [help_msg]
    int 0x21
    jmp prompt
.not_help:
.check_type:
    lea si, [str_type]
    lea di, [input_buffer]
    mov cx, 4
    repe cmpsb
    jne .not_type
.maybe_type:
    call parse_type_or_exec
    cmp ax, 1
    je .not_type
    cmp ax, 2
    je prompt
.type:
    push ds
    lea ax, [0x4000]
    mov ds, ax
    xor ah, ah
    mov bl, 0x7
    xor si, si
    int 0x21
    pop ds
    jmp prompt
.not_type:
    lea si, [input_buffer]
    call move_filename

    mov ax, [directory_block]
    mov cl, [directory_size]
    mov dl, [drive]
    lea si, [filename_buffer]
    int 0x24
    test cl, cl
    jz .failure
    test ch, 0x80
    jnz .failure
    push es
    lea bx, [0x4000]
    mov es, bx
    xor bx, bx
    int 0x22
    pop es

    push cs
    push word return_point
    push word 0x4000
    push word 0
    retf

.failure:
    xor ah, ah
    mov bl, 0x4
    lea si, [error_not_command]
    int 0x21
    mov bl, 0x7

    jmp prompt

return_point:
    mov ax, cs
    mov ds, ax
    mov es, ax

    jmp prompt

move_filename:
    pusha
    lea di, [filename_buffer]
    mov cx, 16
.move_filename_loop:
    lodsb
    test al, al
    jz .set_space
    cmp al, " "
    je .set_space
    stosb
    loop .move_filename_loop
.move_filename_loop_after:
    popa
    ret
.set_space:
    mov al, " "
    stosb
    loop .move_filename_loop
    jmp .move_filename_loop_after

parse_cd:
    mov ax, 0
    pusha
    mov al, [input_buffer+2]
    test al, al
    jz .cd_fail_no_argument
    cmp al, " "
    je .actually_parse
    popa
    mov ax, 1
    ret
.actually_parse:
    lea si, [input_buffer+3]
.find_next_token:
    lodsb
    test al, al
    jz .find_next_token
    cmp al, " "
    je .find_next_token
    cmp al, "/"
    jne .not_root
    mov al, [si]
    test al, al
    jz .root
    cmp al, " "
    je .root
.not_root:
    dec si
    lea di, [filename_buffer]
    mov cx, 16
.move_filename_loop:
    lodsb
    test al, al
    jz .set_space
    cmp al, " "
    je .set_space
    stosb
    loop .move_filename_loop
.move_filename_loop_after:
    xor ax, ax
    mov dl, [drive]
    lea si, [filename_buffer]
    int 0x24
    test cl, cl
    jz .cd_fail_lack
    test ch, 0x80
    jz .cd_fail_type
    mov [directory_block], ax
    mov [directory_size], cl
    lea di, [current_working_directory]
    mov cx, 16
.set_cwd_loop:
    lodsb
    test al, al
    jz .set_zero
    cmp al, " "
    je .set_zero
    stosb
    loop .set_cwd_loop
.set_cwd_loop_after:
    popa
    ret
.set_space:
    mov al, " "
    stosb
    loop .move_filename_loop
    jmp .move_filename_loop_after
.set_zero:
    xor al, al
    stosb
    loop .set_cwd_loop
    jmp .set_cwd_loop_after
.root:
    mov [directory_block], 0
    mov byte [current_working_directory], 0
    popa
    ret
.cd_fail_format:
    xor ah, ah
    mov bl, 0x4
    lea si, [error_cd_format]
    int 0x21
    popa
    mov ax, 2
    ret
.cd_fail_lack:
    xor ah, ah
    mov bl, 0x4
    lea si, [error_dir_not_exist]
    int 0x21
    popa
    mov ax, 2
    ret
.cd_fail_type:
    xor ah, ah
    mov bl, 0x4
    lea si, [error_not_directory]
    int 0x21
    popa
    mov ax, 2
    ret
.cd_fail_no_argument:
    xor ah, ah
    mov bl, 0x4
    lea si, [error_no_argument]
    int 0x21
    popa
    mov ax, 2
    ret

parse_type_or_exec:
    mov ax, 0
    pusha
    mov al, [input_buffer+4]
    test al, al
    jz .fail_no_argument
    cmp al, " "
    je .actually_parse
    popa
    mov ax, 1
    ret
.actually_parse:
    lea si, [input_buffer]
.find_space:
    lodsb
    test al, al
    jz .fail_no_argument
    cmp al, " "
    jne .find_space
    lea di, [filename_buffer]
    mov cx, 16
.move_filename_loop:
    lodsb
    test al, al
    jz .set_space
    cmp al, " "
    je .set_space
    stosb
    loop .move_filename_loop
.move_filename_loop_after:
    mov ax, [directory_block]
    mov cl, [directory_size]
    mov dl, [drive]
    lea si, [filename_buffer]
    int 0x24
    test cl, cl
    jz .fail_lack
    test ch, 0x80
    jnz .fail_type
    push es
    lea bx, [0x4000]
    mov es, bx
    xor bx, bx
    int 0x22
    pop es
    mov ah, 0x1
    mov al, 0xa
    int 0x21
    popa
    ret
.set_space:
    mov al, " "
    stosb
    loop .move_filename_loop
    jmp .move_filename_loop_after
.fail_lack:
    xor ah, ah
    mov bl, 0x4
    lea si, [error_not_exist]
    int 0x21
    popa
    mov ax, 2
    ret
.fail_type:
    xor ah, ah
    mov bl, 0x4
    lea si, [error_not_file]
    int 0x21
    popa
    mov ax, 2
    ret
.fail_no_argument:
    xor ah, ah
    mov bl, 0x4
    lea si, [error_no_argument]
    int 0x21
    popa
    mov ax, 2
    ret

terminate_cwd:
    pusha
    lea si, [current_working_directory]
.loop_through:
    lodsb
    test al, al
    jz .done
    cmp al, " "
    jne .loop_through
    mov byte [si-1], 0
.done:
    mov byte [current_working_directory+16], 0
    popa
    ret

prompt_message:
    pusha
    mov ah, 0x1
    mov al, [drive]
    add al, "A"
    mov bl, 0x7
    int 0x21
    mov al, ":"
    int 0x21
    mov al, "/"
    int 0x21
    call terminate_cwd
    mov al, [current_working_directory]
    test al, al
    jz .arrow
    dec ah
    lea si, [current_working_directory]
    int 0x21
    inc ah
    mov al, "/"
    int 0x21
.arrow:
    mov al, ">"
    int 0x21
    popa
    ret

cwd_message:
    pusha
    mov ah, 0x1
    mov al, [drive]
    add al, "A"
    mov bl, 0x7
    int 0x21
    mov al, ":"
    int 0x21
    mov al, "/"
    int 0x21
    call terminate_cwd
    mov al, [current_working_directory]
    test al, al
    jz .ret
    dec ah
    lea si, [current_working_directory]
    int 0x21
    inc ah
    mov al, "/"
    int 0x21
.ret:
    popa
    ret

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

directory_of db "Directory of ", 0

str_file db "FILE", endl, " ", 0
str_system db "SYSTEM FILE", endl, " ", 0
str_directory db "DIRECTORY", endl, " ", 0

str_cd db "cd", 0
str_cls db "cls", 0
str_dir db "dir", 0
str_help db "help", 0
str_type db "type", 0

help_msg db "List of commands:", endl, \
            "cd <directory name>", endl, \
            "cls", endl, \
            "dir", endl, \
            "help", endl, \
            "type <file name>", endl, \
            "<executable file name>", endl, \
            0

error_cd_format db "Directory format must be like so: DirName (or / for root)", endl, 0
error_not_file db "That is a directory!", endl, 0
error_not_exist db "File specified does not exist.", endl, 0
error_not_directory db "That is a file!", endl, 0
error_dir_not_exist db "Directory specified does not exist.", endl, 0
error_no_argument db "No argument supplied to the command, even though it required one.", endl, 0
error_not_command db "Not a command, nor an executable file.", endl, 0

folder_system db "System          "

drive db ?

directory_block dw ?
directory_size db ?

current_working_directory db 17 dup(?)

input_buffer db 33 dup(?)
MAX_INPUT_SIZE = 32

filename_buffer db 16 dup(?)

buffer rb 8192