[bits 32]

section .kernel32

	;; The interrupt code should be loaded at address 0x9000
KERNEL_START equ _start - 0x9000 ;to convert relocatables to absolute adresses

_start:

idt_setup:

	lidt [idt_descriptor]
	
	call vga_clear_screen	;clearing the screen
	
	mov ebx, BOOT_MSG_32BIT	;this is what will be printed on the screen
	
	mov al, 0x0 		;al should contain the line number
	mov ch, 0x0f 		;dl should contain the color - white on black
	mov cl, 0x0			;ecx should contain the column number
	call vga_print		;we call the print function

	;; Remapping the PICs
	;; This is done because the interrupts of the first PIC are numbered 8-15, which conflicts
	;; with the protected mode exceptions. The second PIC is remapped for convenience.
	;; PIC1 uses interrupts 32-39
	;; PIC2 uses interrupts 40-47
	mov al, 0x11
	out 0x20, al		;restarting PIC1
	out 0xa0, al		;restarting PIC2

	mov al, 0x20
	out 0x21, al		;PIC1 now starts at 32
	mov al, 0x28
	out 0xa1, al		;PIC2 now starts at 40

	;; setting up cascading
	mov al, 0x04
	out 0x21, al
	mov al, 0x02
	out 0xa1, al

	mov al, 0x01
	out 0x21, al
	out 0xa1, al
	;; done

	;; disabling all IRQs except the Keyboard
	mov al, 0xfd
	out 0x21, al	
	out 0xa1, al

	sti
	
	;; After this point, we are making preparations to jump to long mode
	;; First, we check if the CPUID command is available by trying to flip bit 21
	;; in the FLAGS register.

	;; Copying the FLAGS register into eax via the stack
	pushfd
	pop eax

	mov ecx, eax		;; Copying it to ecx for later comparison
	xor eax, 0x00200000	;; We flip the ID bit (bit 21)

	jmp $

idt_start:
	;; pm exception #0 - Divide by zero error (fault) 
	dw (divide_by_zero_handler - KERNEL_START & 0xffff)	;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (divide_by_zero_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #1 - Debug (fault) 
	dw (debug_handler - KERNEL_START & 0xffff)		;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (debug_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #2 - Non Maskable interrupt (interrupt) --TODO
	dw (NMI_handler - KERNEL_START & 0xffff)		;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (NMI_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #3 - Breakpoint (trap)
	dw (Breakpoint_handler - KERNEL_START & 0xffff)		;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (Breakpoint_handler - KERNEL_START >> 16)		;the high bytes of the handler address

	;; pm exception #4 - Overflow (trap)
	dw (Overflow_handler - KERNEL_START & 0xffff)		;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (Overflow_handler - KERNEL_START >> 16)		;the high bytes of the handler address

	;; pm exception #5 - Bound range exceeded (fault)
	dw (OOB_handler - KERNEL_START & 0xffff)		;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (OOB_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #6 - Invalid Opcode (fault)
	dw (UD_handler - KERNEL_START & 0xffff)			;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (UD_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #7 - Device not available (fault)
	;; Attempted an FPU operation but no FPU exists on the machine
	dw (NM_handler - KERNEL_START & 0xffff)			;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (NM_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #8 - Double fault (abort)
	;; A double fault occured, the machine is unrecoverable and is to be rebooted.
	;; This can happen because of an unhandled exception, or when two exception
	;; occur at the same time.
	dw (DF_handler - KERNEL_START & 0xffff)			;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (DF_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #9 - Coprocessor Segment Overrun (fault)
	;; This is legacy, canno occur on modern hardware because FPU is integrated
	dw (CSO_handler - KERNEL_START & 0xffff)		;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (CSO_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #A - Invalid TSS (fault)
	;; Occurs when using an invalid segment selector
	;; An error code is pushed to the stack, containing the invalid selector index
	dw (TS_handler - KERNEL_START & 0xffff)			;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (TS_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #B - Segment not present (fault)
	;; Occurs when trying to use a segment with a present bit set to 0
	;; An error code is pushed to the stack, containing the invalid selector index
	dw (NP_handler - KERNEL_START & 0xffff)			;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (NP_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #C - Stack-Segment Fault (fault)
	;; Occurs when :
	;; - Loading a stack-segment referencing a non-present segment
	;; - PUSH or POP operations using ESP or EBP with a non-canonical stack address
	;; - The stack-limit check fails
	;; An error code is pushed to the stack, containing the invalid selector index if it exists
	dw (SS_handler - KERNEL_START & 0xffff)			;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (SS_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #D - General Protection Fault (fault)
	;; Can occur for many reasons, the most common being :
	;; - A Segment error (privilege, type, etc)
	;; - Executing a privileged instruction when not authorized
	;; - Using invalid registers combinaisons (eg CR0 with PE=0 and PG=1)
	;; - Referencing or accessing a NULL-descriptor
	;;
	;; EIP contains the address of the faulty instruction
	;; An error code is pushed to the stack, containing the invalid selector index if it exists
	dw (GP_handler - KERNEL_START & 0xffff)			;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (GP_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #E - Page Fault (fault)
	;; Can occur when :
	;; - A page directory of table is not present in memory
	;; - An attempt to load the instruction TLB for a non-executable page is made
	;; - A protection check failed
	;; - A reserved bit is set to 1
	;; An error code is pushed to the stack, containing the invalid selector index if it exists
	dw (PF_handler - KERNEL_START & 0xffff)			;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (PF_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #F - Reserved
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #10 - x87 Floating-Point Exception (fault)
	;; Can happen when using the FWAIT or WAIT instruction and :
	;; - CR0.NE is set (Numeric Error)
	;; - An unmasked x87 floating-point exception is pending
	dw (MF_handler - KERNEL_START & 0xffff)			;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (MF_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #11 - Alignment Check failure (fault)
	;; Occurs when alignment checking is enabled (only possible in CPL3) and an unaligned memory
	;; reference is performed
	dw (AC_handler - KERNEL_START & 0xffff)			;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (AC_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #12 - Machine Check Failure (abort)
	;; Processor-specific exception. Can occur when failing on a self-check, for example because
	;; of bad memory, bus errors, cache errors, etc. Disabled by default, enabled by setting
	;; the CR4.MCE bit.
	dw (MC_handler - KERNEL_START & 0xffff)			;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (MC_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #13 - SIMD Floating-Point Exception (fault)
	;; Occurs when an unmasked 128-bit media floating-point exception occurs and the
	;; CR4.OSXMMEXCPT bit is set. Otherwise, this would cause an UD exception.
	dw (XM_handler - KERNEL_START & 0xffff)			;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (XM_handler - KERNEL_START >> 16)			;the high bytes of the handler address

	;; pm exception #14 - Virtualization Exception (fault)
	;; Unhandled for now
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #15 - Control Protection Exception (fault)
	;; Triggered when a control flow transfer attempt did not respect branch
	;; tracking constraints
	;; Unhandled for now
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #16 - Reserved
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #17 - Reserved
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #18 - Reserved
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #19 - Reserved
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #1A - Reserved
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #1B - Reserved
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #1C - Hypervisor Injection Exception
	;; Unhandled for now
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #1D - VMM Communication Exception
	;; Unhandled for now
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #1E - Security Exception (fault)
	;; Unhandled for now
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #1F - Reserved
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #20 - Programmable timer
	dw (unhandled_exception_handler - KERNEL_START & 0xffff);the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (unhandled_exception_handler - KERNEL_START >> 16)	;the high bytes of the handler address

	;; pm exception #21 - Keyboard Interrupt
	dw (keyboard_handler - KERNEL_START & 0xffff)		;the low bytes of the handler address
	dw 0b0000000000001000			;segment selector
	db 0x00							;unused
	db 0x8E							;trap gate in ring 0
	dw (keyboard_handler - KERNEL_START >> 16)		;the high bytes of the handler address
	
times 884 dw 0
	
idt_end:

idt_descriptor:
	dw idt_end - idt_start - 1 ;setting the size of the idt
	dd idt_start			   ;setting up the start of the idt

	;; --------------------------Start of handlers----------------------------- ;;
	;; Each interrupt vector needs its own handler to find what happened

divide_by_zero_handler: 	;Int 0x0
	pusha
	;; We simply print a message showing the user what happened
	mov ebx, DIVIDE_BY_ZERO	;we print an error message
	mov ch, 0x04			;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	popa
	iret 	;non fatal exception

debug_handler: 			;Int 0x1
	pusha
	;; We simply print a message showing the user what happened
	mov ebx, DEBUG		;we print an error message
	mov ch, 0x04		;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	popa
	iret 			;non fatal exception

NMI_handler: 			;Int 0x2
	pusha
	;; We simply print a message showing the user what happened
	mov ebx, NMI		;we print an error message
	mov ch, 0x04		;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	popa
	iret 			;non fatal exception

Breakpoint_handler: 		;Int 0x3
	;; We simply print a message showing the user what happened
	mov ebx, BREAKPOINT_REACHED	;we print an error message
	mov ch, 0x04				;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	cli
	jmp $ 			;we stop the program

Overflow_handler: 		;Int 0x4
	pusha
	;; We simply print a message showing the user what happened
	mov ebx, OVERFLOW		;we print an error message
	mov ch, 0x04			;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	popa
	iret 			;non fatal exception

OOB_handler: 			;Int 0x5
	pusha
	;; We simply print a message showing the user what happened
	mov ebx, OUT_OF_BOUNDS		;we print an error message
	mov ch, 0x04				;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	popa
	iret 			;non fatal exception

UD_handler: 			;Int 0x6
	pusha
	;; We simply print a message showing the user what happened
	mov ebx, INVALID_OPCODE		;we print an error message
	mov ch, 0x04				;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	popa
	iret 			;non fatal exception

NM_handler: 			;Int 0x7
	pusha
	;; We simply print a message showing the user what happened
	mov ebx, DEVICE_NOT_AVAILABLE	;we print an error message
	mov ch, 0x04					;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	popa
	iret 			;non fatal exception

DF_handler:			;Int 0x8
	;; We simply print a message showing the user what happened
	mov ebx, DOUBLE_FAULT		;we print an error message
	mov ch, 0x04				;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	cli
	jmp $ 			;fatal exception

CSO_handler:  			;Int 0x9
	;; We simply print a message showing the user what happened
	mov ebx, COPROCESSOR_OVERRUN	;we print an error message
	mov ch, 0x04					;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	cli
	jmp $ 			;non fatal exception, but we stay here because it should never
	;; happen. This means something is terribly wrong

TS_handler:  			;Int 0xA
	pusha
	;; We print a message showing the user what happened
	mov ebx, INVALID_TSS		;we print an error message
	mov ch, 0x04				;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	pop dword [error_processing_area] ;TODO: print it to the user

	popa
	iret 			;non fatal exception

NP_handler:  			;Int 0xB
	pusha
	;; We print a message showing the user what happened
	mov ebx, SEGMENT_MISSING	;we print an error message
	mov ch, 0x04				;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	pop dword [error_processing_area] ;TODO: print it to the user

	popa
	iret 			;non fatal exception

SS_handler:  			;Int 0xC
	pusha
	;; We print a message showing the user what happened
	mov ebx, STACK_SEGMENT		;we print an error message
	mov ch, 0x04			;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	pop dword [error_processing_area] ;TODO: print it to the user

	popa
	iret 			;non fatal exception

GP_handler:  			;Int 0xD
	pusha
	;; We print a message showing the user what happened
	mov ebx, GENERAL_PROTECTION	;we print an error message
	mov ch, 0x04			;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	pop dword [error_processing_area] ;TODO: print it to the user; print EIP

	popa
	iret 			;non fatal exception

PF_handler:  			;Int 0xE
	
	;; Not implemented yet, as paging is not implemented on this system in protected mode

	pop dword [error_processing_area]

	iret 			;non fatal exception

MF_handler:			;Int 0x10
	pusha
	;; We simply print a message showing the user what happened
	mov ebx, X87_EXCEPTION		;we print an error message
	mov ch, 0x04			;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	popa
	iret 			;non fatal exception

AC_handler:			;Int 0x11

	pusha
	add esp, 4		;The error code is always 0, so we don't need to check it
	;; add esp, 4 is moving the stack pointer higher, ignoring what was previously at
	;; the top
	
	;; We simply print a message showing the user what happened
	mov ebx, X87_EXCEPTION		;we print an error message
	mov ch, 0x04			;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	popa
	iret 			;non fatal exception

MC_handler:			;Int 0x12
	;; We simply print a message showing the user what happened
	mov ebx, MACHINE_CHECK_FAIL	;we print an error message
	mov ch, 0x04			;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	cli
	jmp $ 			;fatal exception

XM_handler:			;Int 0x13
	;; We simply print a message showing the user what happened
	pusha
	mov ebx, SIMD_EXCEPTION		;we print an error message
	mov ch, 0x04			;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	popa
	iret 			;non-fatal exception

keyboard_handler:

	pusha

	xor eax, eax		;Making sure eax will be equal to al by resetting it

	in al, 0x60			;The keyboard scancode is stored in port 0x60

	cmp al, 0x80		;If this is a key release, we ignore it
	ja keyboard_handler_end

	;; This is the part translating the scancodes into the ASCII character equivalent
	mov ebx, scancodes_translations ;Looking up the translation table address
	add ebx, eax			;Adding the right offset (the scancode)
	mov ebx, [ebx]			;We fetch the data at that address
	mov [keyboard_unpack], bl	;We store it in the buffer. The byte is directly followed
			 					;by a NULL byte to only display a single character

	;; Setting the character to be displayed
	mov ebx, keyboard_unpack
	
	mov ch, 0x0f			;white on black
	mov al, 0x00
	mov cl, [keyboard_x]
	
	call vga_print

	;; Adding one to the character position on screen
	mov cl, [keyboard_x]
	add cl, 0x01
	mov [keyboard_x], cl

keyboard_handler_end:

	;; Sending End Of Interrupt (EOI) to the PIC
	mov al, 0x20 		;EOI Code
	out 0x20, al

	popa
	iret 			;returning to the main code

	;; Memory area to create the character to be displayed
keyboard_unpack:
	db 0x00
	db 0x00 		;String terminator
	
unhandled_exception_handler:
	
	mov ebx, UNHANDLED_EXCEPTION  	;we print an error message
	mov ch, 0x04		   		  	;red on black
	mov al, 0x0
	mov cl, 0x0
	
	call vga_print

	cli
	jmp $ 	;We stay here

	;; ---------------------------Error messages------------------------------- ;;
	
	;; the error message when an unhandled exception occurs
	DIVIDE_BY_ZERO db "A division by 0 occured", 0 						;0x00
	DEBUG db "Debug exception reached", 0	       						;0x01
	NMI db "Non maskable interrupt occured", 0     						;0x02
	BREAKPOINT_REACHED db "Breakpoint reached", 0 						;0x03
	OVERFLOW db "An overflow occured before calling INTO", 0 			;0x04
	OUT_OF_BOUNDS db "BOUND noticed out of range array indice", 0 		;0x05
	INVALID_OPCODE db "Invalid Opcode encountered", 0 					;0x06
	DEVICE_NOT_AVAILABLE db "FPU is missing", 0 						;0x07
	DOUBLE_FAULT db "A Double Fault occured", 0 						;0x08
	COPROCESSOR_OVERRUN db "Coprocessor Segment Overrun", 0 			;0x09 - Legacy
	INVALID_TSS db "Invalid Segment Selector used", 0 					;0x0A
	SEGMENT_MISSING db "Segment had present bit set to 0", 0 			;0x0B
	STACK_SEGMENT db "A Stack-Segment fault occured", 0 				;0x0C
	GENERAL_PROTECTION db "A General Protection Fault occured", 0 		;0x0D
	;; A page fault is normal, the user doesn't need to be informed		;0x0E
	;; RESERVED															;0x0F
	X87_EXCEPTION db "x87 FPE occured", 0 								;0x10
	ALIGNMENT_FAILURE db "Alignment Check Failure", 0 					;0x11
	MACHINE_CHECK_FAIL db "Machine Check Failure", 0 					;0x12
	SIMD_EXCEPTION db "SIMD Exception", 0 								;0x13
	;; Virtualization Exception - Not handled							;0x14
	;; Control Protection Exception - Not handled						;0x15
	;; RESERVED															;0x16
	;; RESERVED															;0x17
	;; RESERVED															;0x18
	;; RESERVED															;0x19
	;; RESERVED															;0x1A
	;; RESERVED															;0x1B
	;; Hypervisor Injection Exception									;0x1C
	;; VMM Communication Exception										;0x1D
	;; Security Exception												;0x1E
	;; RESERVED															;0x1F
	;; Programmable Timer												;0x20
	;; Keyboard Interrupt												;0x21
	UNHANDLED_EXCEPTION db "Unhandled exception error", 0

	;; ---------------------------End of handlers------------------------------ ;;

	;; ---------------------32 bit mode print function------------------------- ;;

	;; ebx needs to be pointing to the string to display
	;; al needs to hold the line number to start
	;; ch should contain the color to print
	;; cl needs to hold the column number to start

[bits 32]
vga_print:

	pusha

	xor ah, ah	;Resetting ah, so eax = al

	;; defining constants to make things easier
	VGA_MEMORY_ADDRESS equ 0xb8000
	VGA_MEMORY_END equ 0xb8fa0	 ;0xb8000 + 80*25*2

vga_print_start:

	cmp al, 24d 		;if the line is greater than the screen size
	jg vga_print_scroll 	;we scroll the screen
	;; This is executed the as many times as necessary to make al less than 24
	;; 24 being the last line of the screen in VGA text mode
	
vga_print_offset_calc:

	;; calculating the offset
	;; line offset
	
	mov dx, 0xa0 		;preparing the multiplication to add the right offset (80*2 per line)
	mul dx 				;eax = eax*dx = al*dx

	push ecx 			;saving the color data
	mov ch, 0x00 		;setting ecx so that ecx = cl

	shl ecx, 1			;multiplying ecx by 2 because each VGA slot is 2 bytes long
	add eax, ecx		;adding this to the current offset
	
	mov edx, VGA_MEMORY_ADDRESS 	;setting edx to the base of the VGA space
	add edx, eax					;adding our offset

	cmp edx, VGA_MEMORY_END 		;checking that we still are in VGA MEMORY
	
	jge vga_print_done 	;if not, we exit

	pop ecx
	mov ah, ch 			;we restore the color

vga_print_loop:
	mov al, [ebx] 		;[ebx] is the address of the current character

	cmp al, 0 			;checking if the current character is a NULL byte
	je vga_print_done 	;if yes, we finish

	cmp edx, VGA_MEMORY_END 	;checking that we still are in VGA MEMORY
	jge vga_print_done 			;if not, we exit

	mov [edx], ax 		;we store the character and the color in the vga memory
	add ebx, 1 			;we move to the next character
	add edx, 2 			;we move to the next position on screen (current + 2)

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
	mov ecx, 0 			;ecx will hold the value used to clear the screen
	
vga_print_last_line_clear_loop:
	mov [ebx], ecx 		;we fill it with zeroes
	add ebx, 0x4 		;moving to the next two characters

	cmp ebx, VGA_MEMORY_END  			;if we haven't fully cleaned the last line
	jb vga_print_last_line_clear_loop 	;we loop back to continue
	
	sub al, 1 		;we remove 1 to the line number we want to print to
	pop ecx 		;we restore the registers
	pop ebx

	jmp vga_print_start

	
	;; ---------------------32 bit mode print function------------------------- ;;

	;; ----------------------32 bit mode clear screen-------------------------- ;;

[bits 32]
vga_clear_screen:
	pusha 						;we save the registers
	mov edx, VGA_MEMORY_ADDRESS	;setting edx to the first byte of the VGA memory

	mov al, 0x0 		;NULL character
	mov ah, 0x0f	 	;setting the color

vga_clear_loop:

	mov [edx], ax 	;clearing the character pointed by edx
	add edx, 2 		;moving to the next position on screen
	
	cmp edx, VGA_MEMORY_END	;checking if we cleared the whole screen
	jge vga_clear_done 		;if yes, quitting

	jmp vga_clear_loop 		;if no, looping

vga_clear_done:
	popa 		;restoring the registers
	ret			;returning
	
	;; ----------------------32 bit mode clear screen-------------------------- ;;
	BOOT_MSG_32BIT db "initialized 32bit mode", 0

	;; -------------------------keyboard data area----------------------------- ;;
	
keyboard_x:	db 0x00
keyboard_y:	db 0x00

	;; This holds a table translating scancodes into the corresponding character
scancodes_translations:
	db "*"		;0x00 - Error
	db "*"		;0x01 - Escape
	db "1"		;0x02 - 1
	db "2"		;0x03 - 2
	db "3"		;0x04 - 3
	db "4"		;0x05 - 4
	db "5"		;0x06 - 5
	db "6"		;0x07 - 6
	db "7"		;0x08 - 7
	db "8"		;0x09 - 8
	db "9"		;0x0A - 9
	db "0"		;0x0B - 0
	db ")"		;0x0C - )
	db "="		;0x0D - =
	db "*"		;0x0E - Backspace
	db "*"		;0x0F - Tab
	db "a"		;0x10 - a
	db "z"		;0x11 - z
	db "e"		;0x12 - e
	db "r"		;0x13 - r
	db "t"		;0x14 - t
	db "y"		;0x15 - y
	db "u"		;0x16 - u
	db "i"		;0x17 - i
	db "o"		;0x18 - o
	db "p"		;0x19 - p
	db "^"		;0x1A - ^
	db "$"		;0x1B - $
	db "*"		;0x1C - Enter
	db "*"		;0x1D - Left Ctrl
	db "q"		;0x1E - q
	db "s"		;0x1F - s
	db "d"		;0x20 - d
	db "f"		;0x21 - f
	db "g"		;0x22 - g
	db "h"		;0x23 - h
	db "j"		;0x24 - j
	db "k"		;0x25 - k
	db "l"		;0x26 - l
	db "m"		;0x27 - m
	db "*"		;0x28 - ù (non-ASCII)
	db "*"		;0x29 - ² (non-ASCII)
	db "*"		;0x2A - Left Shift
	db "*"		;0x2B - *
	db "w"		;0x2C - w
	db "x"		;0x2D - x
	db "c"		;0x2E - c
	db "v"		;0x2F - v
	db "b"		;0x30 - b
	db "n"		;0x31 - n
	db ","		;0x32 - ,
	db ";"		;0x33 - ;
	db ":"		;0x34 - :
	db "!"		;0x35 - !
	db "*"		;0x36 - Right Shift
	db "*"		;0x37 - Keypad *
	db "*"		;0x38 - Left Alt
	db " "		;0x39 - SpaceBar
	db "*"		;0x3A - Caps Lock
	db "*"		;0x3B - F1
	db "*"		;0x3C - F2
	db "*"		;0x3D - F3
	db "*"		;0x3E - F4
	db "*"		;0x3F - F5
	db "*"		;0x40 - F6
	db "*"		;0x41 - F7
	db "*"		;0x42 - F8
	db "*"		;0x43 - F9
	db "*"		;0x44 - F10
	db "*"		;0x45 - NumLock
	db "*"		;0x46 - Scroll
	db "7"		;0x47 - Keypad 7
	db "8"		;0x48 - Keypad 8
	db "9"		;0x49 - Keypad 9
	db "-"		;0x4A - Keypad -
	db "4"		;0x4B - Keypad 4
	db "5"		;0x4C - Keypad 5
	db "6"		;0x4D - Keypad 6
	db "+"		;0x4E - Keypad +
	db "1"		;0x4F - Keypad 1
	db "2"		;0x50 - Keypad 2
	db "3"		;0x51 - Keypad 3
	db "0"		;0x52 - Keypad 0
	db "."		;0x53 - Keypad .

	;; ----------------A memory area to process error codes-------------------- ;;
	;; 256 bytes long
	
error_processing_area:
times 256 db 0x00
