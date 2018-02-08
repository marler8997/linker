module inputfile;

import std.typecons : Unique;

//import cpp;
/*
static import llvm;
import llvm : DenseSet;
import llvm.Object.Archive;
import llvm.BinaryFormat.COFF;
*/
import llvm.Support.COFF;
import llvm.Support.MemoryBuffer;
import util;

/*

namespace llvm {
namespace pdb {
class DbiModuleDescriptorBuilder;
}
}

namespace lld {
namespace coff {

vector<MemoryBufferRef> getArchiveMembers(llvm::object::Archive *File);

using llvm::COFF::IMAGE_FILE_MACHINE_UNKNOWN;
using llvm::COFF::MachineTypes;
using llvm::object::Archive;
using llvm::object::COFFObjectFile;
using llvm::object::COFFSymbolRef;
using llvm::object::coff_import_header;
using llvm::object::coff_section;

class Chunk;
class Defined;
class DefinedImportData;
class DefinedImportThunk;
class Lazy;
class SectionChunk;
class Symbol;
class Undefined;
*/

// The root class of input files.
class InputFile
{
    enum Kind : ubyte { archive, obj, import_, bitcode };

    MemoryBufferRef MB;
    // An archive file name if this file is created from an archive.
    string ParentName;
    protected string Directives;
    private const Kind kindMember;

    protected this(Kind kind, MemoryBufferRef mb)
    {
        this.MB = mb;
        this.kindMember = kind;
    }

    static foreach(kind; __traits(allMembers, Kind))
    {
        mixin(`
        @property final auto as` ~ __traits(getMember, Kind, kind).capitalName ~ `File() inout
        {
            return (this.kind == Kind.` ~ kind ~ `) ? ` ~
                ` staticCast!(inout(` ~ __traits(getMember, Kind, kind).capitalName ~ `File))(this) : null;
        }
        `);
    }
    @property final Kind kind() const { return kindMember; }

    // Returns the filename.
    final string getName() const { return MB.getBufferIdentifier(); }

    // Reads a file (the constructor doesn't do that).
    protected abstract void parse();

    // Returns the CPU type this file was compiled to.
    MachineTypes getMachineType() { return MachineTypes.unknown; }

    // Returns .drectve section contents if exist.
    //string getDirectives() { return StringRef(Directives).trim(); }
    
    abstract void toString(scope void delegate(const(char)[]) sink);
};

@property string capitalName(const(InputFile.Kind) kind)
{
    final switch(kind)
    {
        case InputFile.Kind.archive: return "Archive";
        case InputFile.Kind.obj: return "Obj";
        case InputFile.Kind.import_: return "Import";
        case InputFile.Kind.bitcode: return "Bitcode";
    }
}

// .lib or .a file.
class ArchiveFile : InputFile
{
    private:
    //Unique!Archive File;
    string Filename;
    //DenseSet!uint64_t Seen;

    public:
    this(MemoryBufferRef M);
    //static bool classof(const(InputFile) F) { return F.kind() == ArchiveKind; }
    override void parse();

    // Enqueues an archive member load for the given symbol. If we've already
    // enqueued a load for the same archive member, this function does nothing,
    // which ensures that we don't load the same member more than once.
    //void addMember(const Archive.Symbol *Sym);
};

// .obj or .o file. This may be a member of an archive file.
class ObjFile : InputFile {
    public:
    this(MemoryBufferRef M)
    {
        super(Kind.obj, M);
    }
    //static bool classof(const(InputFile) F) { return F.kind() == ObjectKind; }
    override void parse();
    override MachineTypes getMachineType();
    /*
    ArrayRef!(Chunk*) getChunks() { return Chunks; }
    ArrayRef!(SectionChunk*) getDebugChunks() { return DebugChunks; }
    ArrayRef!(Symbol*) getSymbols() { return Symbols; }
    */

    /*
    // Returns a Symbol object for the SymbolIndex'th symbol in the
    // underlying object file.
    Symbol *getSymbol(uint32_t SymbolIndex) {
    return Symbols[SymbolIndex];
    }
    */

    // Returns the underying COFF file.
    //COFFObjectFile *getCOFFObj() { return COFFObj.get(); }

    static Vector!ObjFile Instances;

    // True if this object file is compatible with SEH.
    // COFF-specific and x86-only.
    bool SEHCompat = false;

    // The symbol table indexes of the safe exception handlers.
    // COFF-specific and x86-only.
    //ArrayRef!(llvm.support.ulittle32_t) SXData;

    // Pointer to the PDB module descriptor builder. Various debug info records
    // will reference object files by "module index", which is here. Things like
    // source files and section contributions are also recorded here. Will be null
    // if we are not producing a PDB.
    //llvm.pdb.DbiModuleDescriptorBuilder* ModuleDBI = nullptr;

/+
    private:
    void initializeChunks();
    void initializeSymbols();

    SectionChunk *
    readSection(uint32_t SectionNumber,
    const llvm.object_.coff_aux_section_definition *Def);

    void readAssociativeDefinition(
    COFFSymbolRef COFFSym,
    const llvm.object_.coff_aux_section_definition *Def);

    llvm.Optional!(Symbol*)
    createDefined(COFFSymbolRef Sym,
        ref vector!(const llvm.object_.coff_aux_section_definition*) ComdatDefs);
    Symbol *createRegular(COFFSymbolRef Sym);
    Symbol *createUndefined(COFFSymbolRef Sym);

    unique_ptr!(COFFObjectFile) COFFObj;

    // List of all chunks defined by this file. This includes both section
    // chunks and non-section chunks for common symbols.
    vector!(Chunk*) Chunks;

    // CodeView debug info sections.
    vector!(SectionChunk*) DebugChunks;

    // This vector contains the same chunks as Chunks, but they are
    // indexed such that you can get a SectionChunk by section index.
    // Nonexistent section indices are filled with null pointers.
    // (Because section number is 1-based, the first slot is always a
    // null pointer.)
    vector!(SectionChunk*) SparseChunks;

    // This vector contains a list of all symbols defined or referenced by this
    // file. They are indexed such that you can get a Symbol by symbol
    // index. Nonexistent indices (which are occupied by auxiliary
    // symbols in the real symbol table) are filled with null pointers.
    vector!(Symbol*) Symbols;
    +/
};

// This type represents import library members that contain DLL names
// and symbols exported from the DLLs. See Microsoft PE/COFF spec. 7
// for details about the format.
class ImportFile : InputFile
{
    public:
    this(MemoryBufferRef memoryBuffer)
    {
        super(Kind.import_, memoryBuffer);
        //this.Live = !Config.DoGC;
    }

    //static bool classof(const(InputFile) F) { return F.kind() == ImportKind; }

    static Vector!ImportFile Instances;

    //DefinedImportData* ImpSym;
    //DefinedImportThunk* ThunkSym;
    string DLLName;

    override void parse();

    StringRef ExternalName;
    //const coff_import_header *Hdr;
    //Chunk *Location;

    // We want to eliminate dllimported symbols if no one actually refers them.
    // This "Live" bit is used to keep track of which import library members
    // are actually in use.
    //
    // If the Live bit is turned off by MarkLive, Writer will ignore dllimported
    // symbols provided by this import library member.
    bool Live;
};

// Used for LTO.
class BitcodeFile : InputFile
{
    //Unique!(llvm.lto.InputFile) Obj;
    //Vector!Symbol SymbolBodies;
    public:
    this(MemoryBufferRef M)
    {
        super(Kind.bitcode, M);
    }
    //static bool classof(const(InputFile) F) { return F.kind() == BitcodeKind; }
    //ArrayRef!Symbol getSymbols() { return SymbolBodies; }
    override MachineTypes getMachineType();
    static Vector!BitcodeFile Instances;

    override void parse();
};
