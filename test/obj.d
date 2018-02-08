module obj;

enum ObjectFileFormat : ubyte
{
    omf, coff, elf,
}

enum ObjectFileFormatFlag : ubyte
{
    omf  = 0x01,
    coff = 0x02,
    elf  = 0x04,
}
enum OMF_ONLY  = ObjectFileFormatFlag.omf;
enum COFF_ONLY = ObjectFileFormatFlag.coff;
enum ELF_ONLY  = ObjectFileFormatFlag.elf;
enum COFF_ELF  = cast(ObjectFileFormatFlag)(ObjectFileFormatFlag.coff | ObjectFileFormatFlag.elf);
bool supports(ObjectFileFormatFlag flags, ObjectFileFormat format)
{
    final switch(format)
    {
        case ObjectFileFormat.omf : return (flags & ObjectFileFormatFlag.omf ) != 0;
        case ObjectFileFormat.coff: return (flags & ObjectFileFormatFlag.coff) != 0;
        case ObjectFileFormat.elf : return (flags & ObjectFileFormatFlag.elf ) != 0;
    }
}

// TODO: might need seperate formats for bit modes (16/32/64/...)
version(Windows)
{
    __gshared immutable dmdObjectFormats = [ObjectFileFormat.omf, ObjectFileFormat.coff];
}
else
{
    // TODO: more formats might be supported on non-windows
    __gshared immutable dmdObjectFormats = [ObjectFileFormat.elf];
}