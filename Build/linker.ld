MEMORY
{
  bootsector  (rwx)  : ORIGIN = 0x00007c00, LENGTH = 0x00000200
  kernel32    (rwx)  : ORIGIN = 0x00009000, LENGTH = 0x00002000
  kernel64    (rwx)  : ORIGIN = 0x00011000, LENGTH = 0x00009000
}

SECTIONS
{
    .bootsector : AT(0x0000)
    {

    } > bootsector

    .kernel32 : AT(0x0200)
    {

    } > kernel32

    .kernel64 : AT(0x2000)
    {

    } > kernel64
}