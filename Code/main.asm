[org 0x7c00]
	mov bp, 0x9000 		;setting the stack base pointer
	mov sp, bp 		;the stack is currently empty, so sp = bp

	mov bx, BOOT_MSG_16BIT 	;bx should contain the string address wehn calling print
	call print 		;printing a message showing that we booted in 16bit mode

	call switch_to_32bit
	jmp $ 			;this is a failsafe in case of an error, this should never be executed

[bits 16]
switch_to_32bit:
	cli 			;we disable interrupts
	lgdt [gdt_descriptor] 	;we load the gdt

	;; setting 32 bit mode in cr0
	mov eax, cr0
	or eax, 0x1
	mov cr0, eax

	jmp CODE_SEG:init_32bit ;because we are still in 16bit mode

[bits 32]
init_32bit:
	mov ax, DATA_SEG 	;we update the segment registers
	mov ds, ax
	mov ss, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	mov ebp, 0x90000 	;we move the stack base pointer to the top of the free space
	mov esp, ebp 		;the stack is currently empty

	call start_32bit 	;we move to a 32bit region of code

[bits 32]
start_32bit:			;start of the 32bit mode instructions

	call vga_clear_screen 	;clearing the screen
	
	mov ebx, BOOT_MSG_32BIT ;this is what will be printed on the screen
	mov al, 0x0 		;al should contain the line number
	mov ecx, 0x0		;ecx should contain the column number
	call vga_print 		;we call the print function
	
	hlt 			;we stop the CPU
	

	;; ---------------------16 bit mode print function------------------------- ;;
[bits 16]
print:
	pusha 			;saving the registers

print_start:
	;; moving the right character to the al register and checking for end of string
	mov al, [bx] 		;the bx register should contain the string address at first.
	cmp al, 0
	je done			;if we encounter a NULL byte, the string is over

	;; printing using the BIOS' interrupt 0x10
	mov ah, 0x0e
	int 0x10 		;al contains the char

	;; we increment the bx register and loop
	add bx, 1
	jmp print_start

done:
	;; the string has been fully printed
	popa 			;we restore the registers
	ret 			;we return to the calling address
	
	;; ---------------------16 bit mode print function------------------------- ;;

	;; ---------------------32 bit mode print function------------------------- ;;

	;; ebx needs to be pointing to the string to display
	;; al needs to hold the line number to start
	;; ecx needs to hold the column number to start

[bits 32]
vga_print:

	;; defining constants to make things easier
	VGA_MEMORY_ADDRESS equ 0xb8000
	VGA_MEMORY_END equ 0xb8fa0	 ;0xb8000 + 80*25*2
	WHITE_ON_BLACK equ 0x0f

vga_print_start:
	pusha 				;saving the registers

	;; calculating the offset
	;; line offset
	mov dx, 0xa0 		;preparing the multiplication to add the right offset (80*2 per line)
	mul dx 			;eax = eax*dx = al*dx

	shl ecx, 1		;multiplying ecx by 2 because each VGA slot is 2 bytes long
	add eax, ecx		;adding this to the current offset
	
	mov edx, VGA_MEMORY_ADDRESS 	;setting edx to the base of the VGA space
	add edx, eax			;adding our offset

	cmp edx, VGA_MEMORY_END 	;checking that we still are in VGA MEMORY
	jge vga_print_done 		;if not, we exit

vga_print_loop:
	mov al, [ebx] 		;[ebx] is the address of the current character
	mov ah, WHITE_ON_BLACK 	;setting the color

	cmp al, 0 		;checking if the current character is a NULL byte
	je vga_print_done 	;if yes, we finish

	cmp edx, VGA_MEMORY_END 	;checking that we still are in VGA MEMORY
	jge vga_print_done 		;if not, we exit

	mov [edx], ax 		;we store the character and the color in the vga memory
	add ebx, 1 		;we move to the next character
	add edx, 2 		;we move to the next position on screen (current + 2)

	jmp vga_print_loop 	;we loop until we reach the end

vga_print_done:
	popa 			;we restore the registers
	ret 			;we return to the calling code
	
	;; ---------------------32 bit mode print function------------------------- ;;

	;; ----------------------32 bit mode clear screen-------------------------- ;;

[bits 32]
vga_clear_screen:
	pusha 				;we save the registers
	mov edx, VGA_MEMORY_ADDRESS	;setting edx to the first byte of the VGA memory

	mov al, 0x0 		;NULL character
	mov ah, WHITE_ON_BLACK 	;setting the color

vga_clear_loop:

	mov [edx], ax 		;clearing the character pointed by edx
	add edx, 2 		;moving to the next position on screen
	
	cmp edx, VGA_MEMORY_END	;checking if we cleared the whole screen
	jge vga_clear_done 	;if yes, quitting

	jmp vga_clear_loop 	;if no, looping

vga_clear_done:
	popa 			;restoring the registers
	ret			;returning
	
	;; ----------------------32 bit mode clear screen-------------------------- ;;
	
	;; -------------------------Setting up the GDT----------------------------- ;;

gdt_start:
	;; the GDT always starts with a NULL byte
	dd 0x0
	dd 0x0

	;; GDT for code segment, base = 0x00000000, length = 0xfffff
gdt_code:	
	dw 0xffff 		;segment length (bits 0-15)
	dw 0x0000 		;segment base (bits 0-15)
	db 0x00 		;segment base (bits 16-23)
	db 10011010b 		;flags (8bits)
	db 11001111b 		;flags (4bits) + segment length (bits 16-19)
	db 0x00 		;segment base (bits 24-31)

	;;GDT for data segment, base = 0x00000000, length = 0xfffff
gdt_data:
	dw 0xffff 		;segment length (bits 0-15)
	dw 0x0000 		;segment base (bits 0-15)
	db 0x00 		;segment base (bits 16-23)
	db 10010010b 		;flags (8bits)
	db 11001111b 		;flags (4bits) + segment length (bits 16-19)
	db 0x00 		;segment base (bits 24-31)	dw 0xffff

gdt_end: 			;used to calculate sizes

	;; GDT descriptor
gdt_descriptor:
	dw gdt_end - gdt_start - 1 ;size
	dd gdt_start		   ;address

	CODE_SEG equ gdt_code - gdt_start
	DATA_SEG equ gdt_data - gdt_start
	
	;; -------------------------Setting up the GDT----------------------------- ;;


	BOOT_MSG_16BIT db "starting in 16bit mode", 0
	BOOT_MSG_32BIT db "initialized 32bit mode", 0

times 510-($-$$) db 0 		;filling the first sector up to the magic bytes
dw 0xaa55 			;the magic bytes to inform the BIOS this disk is bootable
