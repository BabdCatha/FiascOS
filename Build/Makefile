# $@ = target file
# $< = first dependency
# $^ = all dependencies

# First rule is the one executed when no parameters are fed to the Makefile
all: run

kernel32.elf: ../Code/kernel32.asm
	nasm $< -f elf -o $@

kernel64.elf: ../Code/kernel64.asm
	nasm $< -f elf -o $@

bootsect.bin: ../Code/bootsect.asm
	nasm $< -f bin -o $@

bootsect.elf: bootsect.bin
	i386-elf-objcopy -I binary -O elf32-i386 --rename-section .data=.bootsector $< $@

os-image.elf: bootsect.elf kernel32.elf kernel64.elf
	i386-elf-ld -o $@ -T linker.ld $^ --oformat elf32-i386

os-image.bin: os-image.elf
	i386-elf-objcopy -O binary $< $@

run: os-image.bin
	qemu-system-x86_64 -drive format=raw,file=$< -d int

clean:
	rm -f *.bin *.elf

