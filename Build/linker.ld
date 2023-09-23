MEMORY
{
  bootsector  (rwx)  : ORIGIN = 0x00007c00, LENGTH = 0x00000200
  kernel32    (rwx)  : ORIGIN = 0x00009000, LENGTH = 0x00001000
  kernel64    (rwx)  : ORIGIN = 0x00001000, LENGTH = 0x00010000
}

SECTIONS
{
    .bootsector : AT(0x0000)
    {

    } > bootsector

    .kernel32 : AT(0x0200)
    {

    } > kernel32

    .kernel64 : AT(0x1000)
    {

    } > kernel64
}