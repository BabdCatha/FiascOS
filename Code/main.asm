[org 0x7c00]
	mov bp, 0x9000 		;setting the stack base pointer
	mov sp, bp 		;the stack is currently empty, so sp = bp

	mov bx, BOOT_MSG_16BIT 	;bx should contain the string address wehn calling print
	call print 		;printing a message showing that we booted in 16bit mode

	;; loading code from the second sector of the disk
	;; dl is set to the boot disk by the BIOS when booting, and hasn't been modified yet
	mov ah, 0x02 		;setting a read operation
	mov dh, 0x01 		;reading 512 bytes (1 sector)
	mov cl, 0x02 		;the first sector after the boot sector
	mov ch, 0x00 		;cylinder 0

	;setting the address (es is 0x0000)
	mov bx, 0x9000
	;; [es:bx] = 0x9000

	call disk_load_16bits
	
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
	mov al, 5d 		;al should contain the line number
	mov ecx, 0x0		;ecx should contain the column number
	call vga_print 		;we call the print function

	mov ebx, BOOT_MSG_32BIT ;this is what will be printed on the screen
	mov al, 25d 		;al should contain the line number
	mov ecx, 0x0		;ecx should contain the column number
	call vga_print 		;we call the print function

	mov ebx, BOOT_MSG_32BIT ;this is what will be printed on the screen
	mov al, 25d 		;al should contain the line number
	mov ecx, 0x5		;ecx should contain the column number
	call vga_print 		;we call the print function
	
	hlt 			;we stop the CPU

	;; ----------------------16 bit disk read function------------------------- ;;

	;; [es;bx] should contain the memory address to which the data will be written
	
	;; ah should contain the operation code (0x02 for read)
	;; dl should contain the disk (0x00 for floppy1, 0x80 for hdd1...)
	;; dh should contain the number of sectors to read (between 0x01 and 0x80)
	;; cl should contain the sector to read (between 0x01 and 0x11)
	;; ch should contain the cylinder (between 0x0 and 0x3ff)

[bits 16]
disk_load_16bits:
	pusha
	push dx 		;the dx register will need to be overwritten, and is
	;; necessary to keep to later know if we read the correct amount of sectors

	mov al, dh 		;setting the numbers of sectors to read
	mov dh, 0 		;head 0
	
	int 0x13 		;BIOS interrupt for disk operation
	jc disk_read_error 	;if an error occuped (stored in the carry bit)

	;; if no error occured
	pop dx 			;we restore dx to compare to what was read
	cmp al, dh 		;doing the comparison
	jne disk_sectors_error 	;in case of an error

	;; no error at all
	popa 			;we restore the registers
	ret			;we return

disk_read_error:
	mov bx, DISK_READ_ERROR
	call print 		;printing the error in 16bit mode
	jmp $

disk_sectors_error:
	mov bx, DISK_SECTORS_ERROR
	call print
	jmp $
	

	;; ----------------------16 bit disk read function------------------------- ;;
	
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
	
	pusha 				;saving the registers

vga_print_start:

	cmp al, 24d 		;if the line is greater than the screen size
	jg vga_print_scroll 	;we scroll the screen
	;; This is executed the as many times as necessary to make al less than 23
	;; 23 being the last line of the screen in VGA text mode
	
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

	DISK_READ_ERROR db "Error while reading disk", 0
	DISK_SECTORS_ERROR db "Wrong number of sectors read", 0

times 510-($-$$) db 0 		;filling the first sector up to the magic bytes
dw 0xaa55 			;the magic bytes to inform the BIOS this disk is bootable

times 1024 dw 0xbeef 		;dummy data for now
