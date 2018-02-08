module llvm.Object.COFF;

struct coff_file_header {
    support::ulittle16_t Machine;
    support::ulittle16_t NumberOfSections;
    support::ulittle32_t TimeDateStamp;
    support::ulittle32_t PointerToSymbolTable;
    support::ulittle32_t NumberOfSymbols;
    support::ulittle16_t SizeOfOptionalHeader;
    support::ulittle16_t Characteristics;

    bool isImportLibrary() const { return NumberOfSections == 0xffff; }
};


// Contains only common parts of coff_symbol16 and coff_symbol32.
struct coff_symbol_generic
{
    union {
    char ShortName[COFF::NameSize];
    StringTableOffset Offset;
    } Name;
    support::ulittle32_t Value;
};