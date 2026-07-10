/* PRX linker script for PS3 - forces 3 program segments like Sony SDK -mprx */
PHDRS
{
    text PT_LOAD FLAGS(5);    /* R+X */
    data PT_LOAD FLAGS(6);    /* R+W */
    prx  0x700000A4;          /* LOPROC+0xA4 = PRX parameter segment */
}

SECTIONS
{
    . = 0;

    /* Text segment */
    .text : { *(.text) } : text
    .rodata : { *(.rodata) *(.rodata.*) } : text
    .sceStub.text : { *(.sceStub.text) } : text
    .rodata.sceResident : { *(.rodata.sceResident) } : text

    . = ALIGN(0x10000);
    /* Data segment */
    .ctors : { *(.ctors) } : data
    .data : { *(.data) *(.data.*) } : data
    .data.sceFStub : { *(.data.sceFStub) } : data
    .opd : { *(.opd) } : data
    .got : { *(.got) } : data
    .bss : { *(.bss) *(COMMON) } : data
    .tbss : { *(.tbss) } : data

    . = ALIGN(0x10);
    /* PRX parameter segment - contains import/export tables */
    .lib.ent : {
        . = ALIGN(4);
        __libentstart = .;
        KEEP(*(.lib.ent))
        . = ALIGN(4);
        __libentend = .;
    } : prx

    .lib.stub : {
        . = ALIGN(4);
        __libstubstart = .;
        KEEP(*(.lib.stub))
        . = ALIGN(4);
        __libstubend = .;
    } : prx

    .rodata.sceFNID : { KEEP(*(.rodata.sceFNID)) } : prx

    .sys_proc_param : { KEEP(*(.sys_proc_param)) } : prx
    .sys_proc_prx_param : { KEEP(*(.sys_proc_prx_param)) } : prx
}
