module llvm.Support.COFF;

enum MachineTypes {
    unknown   = 0x0,
    am33      = 0x13,
    amd64     = 0x8664,
    arm       = 0x1C0,
    armnt     = 0x1C4,
    ebc       = 0xEBC,
    i386      = 0x14C,
    ia64      = 0x200,
    m32r      = 0x9041,
    mips16    = 0x266,
    mipsfpu   = 0x366,
    mipsfpu16 = 0x466,
    powerpc   = 0x1F0,
    powerpcfp = 0x1F1,
    r4000     = 0x166,
    sh3       = 0x1A2,
    sh3dsp    = 0x1A3,
    sh4       = 0x1A6,
    sh5       = 0x1A8,
    thumb     = 0x1C2,
    wcemipsv2 = 0x169
};