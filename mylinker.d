module mylinker;

alias MyLinker = LinkerTemplate!LinkerPolicy;
struct LinkerPolicy
{
    /**
    A "Linker Core" is a component that can link objects together.
    There are seperate cores for each format type in order to maximize performance.
    In most cases an application will only use one kind of object format at a time, i.e. 
    COFF/ELF/etc. This idea is taken from the LLVM lld linker, which uses a similar approach and has seen
    tremendous performance gains.
    
    Note that each core also supports a set of inputs.  In the rare case that a core wants
    to support multiple formats in one core, they can add an extra InputFormat (configured below).
    */ 
    enum CoffCore_Enabled = true;
    enum ElfCore_Enabled = true;
    enum OmfCore_Enabled = true;
    
    //
    // Core Specific Configuration
    //
    enum CoffCore_InputFormat_CoffObjectFile = true;
    enum CoffCore_InputFormat_ElfObjectFile = true; // Probably not used that often
    enum CoffCore_InputFormat_CoffDataStructure = true; // InMemory format
    // TODO: Provide a way to customize what the core can do with undefined symbols, i.e.
    //       it could callback with a list of undefined symbols and the client could
    //       resolve them by adding more objects to the link.
    
    //
    // Unmanglers
    //
    enum DUnmangler_Enabled = true;
    enum GnuCppUnmangler_Enabled = true;
    enum MSVCUnmangler_Enabled = true;
    /**
    An application may want to provide custom unmangler callbacks
    because they use unmangling code that lives elsewhere.  This allows that code
    to live outside of the linker, however, an application could also add their
    unmangling code to the linker and let it live in the linker and use it
    by calling into the linker library.
    */
    //enum CustomUnmangers = Tuple!(MyCoolUnmangler, AnotherUnmangler);
    
    //
    // Extensions
    //
    
    
}