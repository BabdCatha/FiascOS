# $@ = target file
# $< = first dependency
# $^ = all dependencies

# First rule is the one executed when no parameters are fed to the Makefile
all: run

# Notice how dependencies are built as needed
interruptions.bin: interruptions.o
	i386-elf-ld -o $@ -Ttext 0x9000 $^ --oformat binary

interruptions.o: ../Code/interruptions.asm
	nasm $< -f elf -o $@

bootsect.bin: ../Code/bootsect.asm
	nasm $< -f bin -o $@

os-image.bin: bootsect.bin interruptions.bin
	cat $^ > $@

run: os-image.bin
	qemu-system-x86_64 -drive format=raw,file=$< -d int

clean:
	rm *.bin *.o

