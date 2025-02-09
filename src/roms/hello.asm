; COLECOVISION - HELLO WORLD!
; By Daniel Bienvenu, 2010
; To be compiled with TNIASM

   fname "hello.rom"
   cpu Z80         ; switch to Z80 mode

   org $8000

   db $aa,$55
   dw 0,0,0
Start:
   nop
   ret
   dw Start
   dw 0,0,0,0,0,0,0,0,0,0,0
   retn
   db "HELLO WORLD!/ /2010"
