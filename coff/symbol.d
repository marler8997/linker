module coff.symbol;

import std.bitmanip : bitfields;

import coff.chunks;
import coff.inputfile;

class Symbol
{
    enum Kind : ubyte
    {
        // The order of these is significant. We start with the regular defined
        // symbols as those are the most prevelant and the zero tag is the cheapest
        // to set. Among the defined kinds, the lower the kind is preferred over
        // the higher kind when testing wether one symbol should take precedence
        // over another.
        DefinedRegularKind = 0,
        DefinedCommonKind,
        DefinedLocalImportKind,
        DefinedImportThunkKind,
        DefinedImportDataKind,
        DefinedAbsoluteKind,
        DefinedSyntheticKind,

        UndefinedKind,
        LazyKind,

        LastDefinedCOFFKind = DefinedCommonKind,
        LastDefinedKind = DefinedSyntheticKind,
    };

    const Kind SymbolKind;

    mixin(bitfields!(
        // TODO: should be protected
        bool, "IsExternal", 1,
        // TODO: should be protected
        // This bit is used by the \c DefinedRegular subclass.
        bool, "IsCOMDAT", 1,

        // This bit is used by Writer::createSymbolAndStringTable() to prevent
        // symbols from being written to the symbol table more than once.
        bool, "WrittenToSymtab", 1,
        // True if this symbol was referenced by a regular (non-bitcode) object.
        bool, "IsUsedInRegularObj", 1,
        // True if we've seen both a lazy and an undefined symbol with this symbol
        // name, which means that we have enqueued an archive member load and should
        // not load any more archive members to resolve the same symbol.
        bool, "PendingArchiveLoad", 1,
        /// True if we've already added this symbol to the list of GC roots.
        bool, "IsGCRoot", 1,
        void, null, 2,
    ));
    protected string Name;

    this(Kind kind, string name = "")
    {
        this.SymbolKind = kind;
        this.Name = name;
        this.IsExternal = true;
        this.IsCOMDAT = false;
        this.WrittenToSymtab = false;
        this.PendingArchiveLoad = false;
        this.IsGCRoot = false;
    }

    Kind kind() const { return SymbolKind; }

    // Returns true if this is an external symbol.
    bool isExternal() { return IsExternal; }

    // Returns the symbol name.
    string getName();

    // Returns the file from which this symbol was created.
    InputFile getFile();

    // Indicates that this symbol will be included in the final image. Only valid
    // after calling markLive.
    bool isLive() const;

    abstract void toString(scope void delegate(const(char)[]) sink);
}

// The base class for any defined symbols, including absolute symbols,
// etc.
class Defined : Symbol
{
    this(Symbol.Kind kind, string name)
    {
        super(kind, name);
    }

    static bool classof(const Symbol* symbol) { return symbol.kind <= Symbol.Kind.LastDefinedKind; }

    // Returns the RVA (relative virtual address) of this symbol. The
    // writer sets and uses RVAs.
    pragma(inline) final ulong getRVA()
    {
        final switch (SymbolKind)
        {
        case DefinedAbsoluteKind:
            return cast(DefinedAbsolute)(this).getRVA();
        case DefinedSyntheticKind:
            return cast(DefinedSynthetic)(this).getRVA();
        case DefinedImportDataKind:
            return cast(DefinedImportData)(this).getRVA();
        case DefinedImportThunkKind:
            return cast(DefinedImportThunk)(this).getRVA();
        case DefinedLocalImportKind:
            return cast(DefinedLocalImport)(this).getRVA();
        case DefinedCommonKind:
            return cast(DefinedCommon)(this).getRVA();
        case DefinedRegularKind:
            return cast(DefinedRegular)(this).getRVA();
        case LazyKind:
        case UndefinedKind:
            llvm_unreachable("Cannot get the address for an undefined symbol.");
        }
        llvm_unreachable("unknown symbol kind");
    }

    // Returns the chunk containing this symbol. Absolute symbols and __ImageBase
    // do not have chunks, so this may return null.
    pragma(inline) final Chunk* getChunk()
    {
        switch (SymbolKind)
        {
        case DefinedRegularKind:
            return cast(DefinedRegular)(this).getChunk();
        case DefinedAbsoluteKind:
            return nullptr;
        case DefinedSyntheticKind:
            return cast(DefinedSynthetic)(this).getChunk();
        case DefinedImportDataKind:
            return cast(DefinedImportData)(this).getChunk();
        case DefinedImportThunkKind:
            return cast(DefinedImportThunk)(this).getChunk();
        case DefinedLocalImportKind:
            return cast(DefinedLocalImport)(this).getChunk();
        case DefinedCommonKind:
            return cast(DefinedCommon)(this).getChunk();
        case LazyKind:
        case UndefinedKind:
            llvm_unreachable("Cannot get the chunk of an undefined symbol.");
        }
        llvm_unreachable("unknown symbol kind");
    }
};

// Symbols defined via a COFF object file or bitcode file.  For COFF files, this
// stores a coff_symbol_generic*, and names of internal symbols are lazily
// loaded through that. For bitcode files, Sym is nullptr and the name is stored
// as a StringRef.
class DefinedCOFF : Defined
{
    InputFile* fileile;
    protected:
    const coff_symbol_generic *Sym;

    this(Kind kind, InputFile* file, string name, const(coff_symbol_generic)* sym)
    {
        super(kind, name);
        this.File = file;
        this.Sym = sym;
    }

    static bool classof(const Symbol* symbol) { return symbol.kind <= Symbol.Kind.LastDefinedCOFFKind; }

    InputFile *getFile() { return File; }
    COFFSymbolRef getCOFFSymbol();
};

// Regular defined symbols read from object file symbol tables.
class DefinedRegular : DefinedCOFF
{
    SectionChunk** Data;

    this(InputFile* file, string name, bool IsCOMDAT, bool IsExternal = false,
        const(coff_symbol_generic)* sym = null, SectionChunk* chunk = null)
    {
        super(DefinedRegularKind, file, name, sym);
        this.Data = chunk ? &chunk.Repl : null;
        this.IsExternal = IsExternal;
        this.IsCOMDAT = IsCOMDAT;
    }

    static bool classof(const Symbol* symbol) { return symbol.kind == Symbol.Kind.DefinedRegularKind; }

    uint64_t getRVA() const { return (*Data).getRVA() + Sym.Value; }
    bool isCOMDAT() const { return IsCOMDAT; }
    SectionChunk *getChunk() const { return *Data; }
    uint32_t getValue() const { return Sym.Value; }
};

class DefinedCommon : DefinedCOFF
{
    private CommonChunk *Data;
    private uint64_t Size;

    this(InputFile* file, string name, uint64_t Size,
    const coff_symbol_generic *S = nullptr,
    CommonChunk *C = nullptr)
    {
        super(DefinedCommonKind, file, name, Size);
        this.Data = C;
        this.Size = Size;
        this.IsExternal = true;
    }
    
    static bool classof(const Symbol* symbol) { return symbol.kind == Symbol.Kind.DefinedCommonKind; }

    uint64_t getRVA() { return Data.getRVA(); }
    CommonChunk *getChunk() { return Data; }

    private:
    uint64_t getSize() const { return Size; }
};

// Absolute symbols.
class DefinedAbsolute : Defined {
    public:
    this(string name, COFFSymbolRef symbolRef)
    {
        super(DefinedAbsoluteKind, name);
        this.VA = symbolRef.getValue();
        this.IsExternal = symbolRef.isExternal();
    }

    this(string name, uint64_t va)
    {
        super(DefinedAbsoluteKind, name);
        this.VA = va;
    }

    static bool classof(const Symbol* symbol) { return symbol.kind == Symbol.Kind.DefinedAbsoluteKind; }

    final uint64_t getRVA() { return VA - Config.ImageBase; }
    final void setVA(uint64_t V) { VA = V; }

    // The sentinel absolute symbol section index. Section index relocations
    // against absolute symbols resolve to this 16 bit number, and it is the
    // largest valid section index plus one. This is written by the Writer.
    static uint16_t OutputSectionIndex;
    final uint16_t getSecIdx() { return OutputSectionIndex; }

    private:
    uint64_t VA;
};

// This symbol is used for linker-synthesized symbols like __ImageBase and
// __safe_se_handler_table.
class DefinedSynthetic : Defined {
    private:
    Chunk *C;
    public:
    this(string name, Chunk *chunk)
    {
        super(DefinedSyntheticKind, name);
        this.C = chunk;
    }

    static bool classof(const Symbol* symbol) { return symbol.kind == Symbol.Kind.DefinedSyntheticKind; }

    // A null chunk indicates that this is __ImageBase. Otherwise, this is some
    // other synthesized chunk, like SEHTableChunk.
    uint32_t getRVA() { return C ? C.getRVA() : 0; }
    Chunk *getChunk() { return C; }

};

// This class represents a symbol defined in an archive file. It is
// created from an archive file header, and it knows how to load an
// object file from an archive to replace itself with a defined
// symbol. If the resolver finds both Undefined and Lazy for
// the same name, it will ask the Lazy to load a file.
class Lazy : Symbol {
    ArchiveFile *File;
    private:
    const Archive.Symbol Sym;
    public:
    this(ArchiveFile *fileF, const Archive.Symbol sym)
    {
        super(LazyKind, sym.getName());
        this.File = file;
        this.Sym = sym;
    }

    static bool classof(const(Symbol)* S) { return S.kind() == LazyKind; }
};

// Undefined symbols.
class Undefined : Symbol {
    public:
    this(string name)
    {
        super(UndefinedKind, name);
    }

    static bool classof(const(Symbol)* S) { return S.kind() == UndefinedKind; }

    // An undefined symbol can have a fallback symbol which gives an
    // undefined symbol a second chance if it would remain undefined.
    // If it remains undefined, it'll be replaced with whatever the
    // Alias pointer points to.
    Symbol* WeakAlias = nullptr;

    // If this symbol is external weak, try to resolve it to a defined
    // symbol by searching the chain of fallback symbols. Returns the symbol if
    // successful, otherwise returns null.
    Defined* getWeakAlias();
};

// Windows-specific classes.

// This class represents a symbol imported from a DLL. This has two
// names for internal use and external use. The former is used for
// name resolution, and the latter is used for the import descriptor
// table in an output. The former has "__imp_" prefix.
class DefinedImportData : Defined
{
    ImportFile *File;
    public:
    this(string name, ImportFile *file)
    {
        super(DefinedImportDataKind, name);
        this.File = file;
    }

    static bool classof(const(Symbol)* S) { return S.kind() == DefinedImportDataKind; }

    uint64_t getRVA() { return File.Location.getRVA(); }
    Chunk *getChunk() { return File.Location; }
    void setLocation(Chunk *AddressTable) { File.Location = AddressTable; }

    StringRef getDLLName() { return File.DLLName; }
    StringRef getExternalName() { return File.ExternalName; }
    uint16_t getOrdinal() { return File.Hdr.OrdinalHint; }
};

// This class represents a symbol for a jump table entry which jumps
// to a function in a DLL. Linker are supposed to create such symbols
// without "__imp_" prefix for all function symbols exported from
// DLLs, so that you can call DLL functions as regular functions with
// a regular name. A function pointer is given as a DefinedImportData.
class DefinedImportThunk : Defined {
    public:
    this(string name, DefinedImportData *S, uint16_t Machine);

    static bool classof(const(Symbol)* S) { return S.kind() == DefinedImportThunkKind; }

    uint64_t getRVA() { return Data.getRVA(); }
    Chunk *getChunk() { return Data; }

    DefinedImportData *WrappedSym;

    private:
    Chunk *Data;
};

// If you have a symbol "__imp_foo" in your object file, a symbol name
// "foo" becomes automatically available as a pointer to "__imp_foo".
// This class is for such automatically-created symbols.
// Yes, this is an odd feature. We didn't intend to implement that.
// This is here just for compatibility with MSVC.
class DefinedLocalImport : Defined {
    private:
    LocalImportChunk *Data;
    public:
    this(string name, Defined* S)
    {
        super(DefinedLocalImportKind, name);
        this.Data = make!LocalImportChunk(S);
    }

    static bool classof(const(Symbol)* S) { return S.kind() == DefinedLocalImportKind; }

    uint64_t getRVA() { return Data.getRVA(); }
    Chunk *getChunk() { return Data; }

};


// A buffer class that is large enough to hold any Symbol-derived
// object. We allocate memory using this class and instantiate a symbol
// using the placement new.
union SymbolUnion
{
    align(DefinedRegular.alignof)     ubyte[DefinedRegular.sizeof]     A;
    align(DefinedCommon.alignof)      ubyte[DefinedCommon.sizeof]      B;
    align(DefinedAbsolute.alignof)    ubyte[DefinedAbsolute.sizeof]    C;
    align(DefinedSynthetic.alignof)   ubyte[DefinedSynthetic.sizeof]   D;
    align(Lazy.alignof)               ubyte[Lazy.sizeof]               E;
    align(Undefined.alignof)          ubyte[Undefined.sizeof]          F;
    align(DefinedImportData.alignof)  ubyte[DefinedImportData.sizeof]  G;
    align(DefinedImportThunk.alignof) ubyte[DefinedImportThunk.sizeof] H;
    align(DefinedLocalImport.alignof) ubyte[DefinedLocalImport.sizeof] I;
}

void replaceSymbol(T, ArgT...)(Symbol* S, ArgT args)
{
    static assert(T.sizeof <= SymbolUnion.sizeof, "Symbol too small");
    static assert(T.alignof <= SymbolUnion.alignof, "SymbolUnion not aligned enough");
    assert(cast(Symbol)cast(T)null is null, "Not a Symbol");
    assert(0, "not implemented");
    //new (S) T(std::forward<ArgT>(Arg)...);
}