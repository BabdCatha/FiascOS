ENTRY(_start)

MEMORY
{
  kernel32    (rwx)  : ORIGIN = 0x00009000, LENGTH = 0x00002000
  kernel64    (rwx)  : ORIGIN = 0x00011000, LENGTH = 0x00009000
}

SECTIONS
{

    .kernel32 :
    {

    } > kernel32

    .kernel64 :
    {

    } > kernel64
}