[bits 32]

global _start
_start:

idt_setup:

	;; ;; lidt [idt_descriptor]

	;; int 0x0
	
	call vga_clear_screen	;clearing the screen
	
	mov ebx, BOOT_MSG_32BIT	;this is what will be printed on the screen
	
	mov al, 0x0 		;al should contain the line number
	mov ecx, 0x0		;ecx should contain the column number
	call vga_print		;we call the print function

	mov ecx, 0xdeadbeef
	jmp $

	call unhandled_exception_handler

	jmp $

idt_start:
	;; interrupt #0 ()
	dw (unhandled_exception_handler - idt_setup & 0xffff)	;the low bytes of the handler address
	dw 0b0000000000001000					;trap gate in ring 0
	db 0x00							;unused
	db 0b10001111						;segment selector
	dw (unhandled_exception_handler - idt_setup >> 16)	;the high bytes of the handler address
idt_end:

idt_descriptor:
	dw idt_end - idt_start - 1 ;setting the size of the idt
	dd idt_start		   ;setting up the start of the idt
	
	;; the error message when an unhandled exception occurs
	UNHANDLED_EXCEPTION db "Unhandled exception error", 0
	
unhandled_exception_handler:
	
	mov ebx, UNHANDLED_EXCEPTION ;we print an error message
	mov al, 0x0
	mov ecx, 0x0
	
	call vga_print

	jmp $ 			;infinite loop

	;; ---------------------32 bit mode print function------------------------- ;;

	;; ebx needs to be pointing to the string to display
	;; al needs to hold the line number to start
	;; ecx needs to hold the column number to start

[bits 32]
vga_print:

	pusha

	;; defining constants to make things easier
	VGA_MEMORY_ADDRESS equ 0xb8000
	VGA_MEMORY_END equ 0xb8fa0	 ;0xb8000 + 80*25*2
	WHITE_ON_BLACK equ 0x0f

vga_print_start:

	cmp al, 24d 		;if the line is greater than the screen size
	jg vga_print_scroll 	;we scroll the screen
	;; This is executed the as many times as necessary to make al less than 24
	;; 24 being the last line of the screen in VGA text mode
	
vga_print_offset_calc:

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

vga_print_scroll:
	push ebx 		;ebx will hold the address we are currently copying
	push ecx 		;ecx will hold the 32bits we are copying at each step
	;; We will start at line 1, column 0, and move forward from there. Each time
	;; copying the current 4 bytes to the line before;

	mov ebx, VGA_MEMORY_ADDRESS + 0xa0 ;address of line 1, col0

vga_print_scroll_loop:	
	mov ecx, [ebx]			   ;moving the data at address [ebx] to ecx
	mov [ebx - 0xa0], ecx		   ;moving the data from ecx to the memory
	add ebx, 0x4			   ;we move to the next the characters

	cmp ebx, VGA_MEMORY_END  ;if we haven't copied the whole screen
	jb vga_print_scroll_loop ;we loop back to continue

	;; at this point, the screen has been copied one line higher
	;; we need to clear the last line

	sub ebx, 0xa0 		;we come back to the begining of the last line
	mov ecx, 0 		;ecx will hold the value used to clear the screen
	
vga_print_last_line_clear_loop:
	mov [ebx], ecx 		;we fill it with zeroes
	add ebx, 0x4 		;moving to the next two characters

	cmp ebx, VGA_MEMORY_END  		;if we haven't fully cleaned the last line
	jb vga_print_last_line_clear_loop 	;we loop back to continue
	
	sub al, 1 		;we remove 1 to the line number we want to print to
	pop ecx 		;we restore the registers
	pop ebx

	jmp vga_print_start

	
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
	BOOT_MSG_32BIT db "initialized 32bit mode", 0
