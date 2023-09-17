MEMORY
{
  bootsector  (rwx)  : ORIGIN = 0x00007c00, LENGTH = 0x00000200
  kernel      (rwx)  : ORIGIN = 0x00009000, LENGTH = 0x00008000
}

SECTIONS
{
    .bootsector : AT(0x0000)
    {

    } > bootsector

    .kernel : AT(0x0200)
    {

    } > kernel
}