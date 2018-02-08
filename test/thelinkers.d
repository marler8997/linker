module thelinkers;

import std.array : Appender;
import std.format : format, formattedWrite;
import std.conv : to;
import std.path : buildPath, dirName;
import std.stdio;
import std.file : exists, dirEntries, SpanMode;

import util : StringSink, putf, formatQuotedIfSpaces, formatDir, quit, run;
import obj : ObjectFileFormatFlag, COFF_ONLY, ELF_ONLY, OMF_ONLY, COFF_ELF;

enum LinkerName
{
    link,
    ld,
    lld_link, // llvm linker with microsoft interface
    optlink,
    ylink,
}

struct LinkerOptions
{
    string exeName;
    //string sdkPath;
    //string kitPath;
    Appender!(string[]) extraLibraryPaths;
}

struct Linker
{
    LinkerName name;
    string defaultExeName;
    string owner;
    ObjectFileFormatFlag objectFileFormats;
    LinkerExe function(const(Linker)* linker, ref const(LinkerOptions) options) createExe;
    @property auto nameString() const { return name.to!string; }
}
__gshared immutable linkers = [
    immutable Linker(LinkerName.link    , "link"    , "Microsoft"    , COFF_ONLY, &MicrosoftLinkerExe.create),
    immutable Linker(LinkerName.ld      , "ld"      , "GNU"          , ELF_ONLY , &notImplemented),
    immutable Linker(LinkerName.lld_link, "lld-link", "LLVM"         , COFF_ELF , &MicrosoftLinkerExe.create),
    immutable Linker(LinkerName.optlink , "link"    , "Digital Mars" , OMF_ONLY , &optlinkCreateLinkerExe),
    immutable Linker(LinkerName.ylink   , "ylink"   , "Daniel Murphy", OMF_ONLY , &notImplemented),
];
auto tryGetLinker(const(char)[] linkerNameString)
{
    foreach(ref linker; linkers)
    {
        if(linker.nameString == linkerNameString)
        {
            return &linker;
        }
    }
    return null;
}

LinkerExe notImplemented(const(Linker)* linker, ref const(LinkerOptions) options) { assert(0, "not implemented"); }

LinkerExe optlinkCreateLinkerExe(const(Linker)* linker, ref const(LinkerOptions) options)
{
    //assert(options.sdkPath is null);
    //assert(options.kitPath is null);
    assert(options.extraLibraryPaths.data.length == 0);
    return new DefaultLinkerExe(linker, options.exeName, &OptlinkCall.create);
}

static assertExists(const(char)[] filename, string whatFormat)
{
    if(!exists(filename))
    {
        writefln("Error: %s does not exist", format(whatFormat, filename));
        throw quit;
    }
}

class LinkerExe
{
    abstract LinkerCall createCall();
}
class DefaultLinkerExe : LinkerExe
{
    string exeName;
    private LinkerCall function(string linkerExe) createCallFunction;
    this(const(Linker)* linker, string exeName, LinkerCall function(string linkerExe) createCallFunction)
    {
        if(exeName is null)
        {
            this.exeName = linker.defaultExeName;
        }
        else
        {
            if(!exists(exeName))
            {
                writefln("Error: linker '%s' does not exist", exeName);
                throw quit;
            }
            this.exeName = exeName;
        }
        this.createCallFunction = createCallFunction;
    }
    final override LinkerCall createCall()
    {
        return createCallFunction(exeName);
    }
}
class MicrosoftLinkerExe : LinkerExe
{
    static LinkerExe create(const(Linker)* linker, ref const(LinkerOptions) options)
    {
        return new MicrosoftLinkerExe(linker, options);
    }
    static void dumpDirs(string path, string itemName)
    {
        uint dirCount = 0;
        if(exists(path))
        {
            foreach(entry; dirEntries(path, SpanMode.shallow))
            {
                if(entry.isDir)
                {
                    if(dirCount == 0)
                    {
                        writefln("Found the following %ss:", itemName);
                    }
                    dirCount++;
                    writefln("%s", entry.name.formatDir);
                }
            }
        }
        if(dirCount == 0)
        {
            writeln("Failed to find any %ss installed to '%s'", itemName, path);
        }
    }
    static void dumpSdks()
    {
        dumpDirs("C:\\Program Files (x86)\\Microsoft SDKs\\Windows", "SDK");
    }
    static void dumpKits()
    {
        dumpDirs("C:\\Program Files (x86)\\Windows Kits", "KIT");
    }

    string exeName;
    string exeLibDir;
    const(Appender!(string[])) extraLibraryPaths;
    //string sdkLibPath;
    //string kitLibPath;
    this(const(Linker)* linker, ref const(LinkerOptions) options)
    {
        // TODO: check if we are in a Visual Studio environment

        if(options.exeName is null)
        {
            this.exeName = linker.defaultExeName;
        }
        else
        {
            assertExists(options.exeName, "the Microsoft linker '%s'");
            this.exeName = options.exeName;
        }

        foreach(libPath; options.extraLibraryPaths.data)
        {
            assertExists(libPath, "the library path %s");
        }
        this.extraLibraryPaths = options.extraLibraryPaths;

        /+
        //
        // exe lib path
        //
        this.exeLibDir = buildPath(options.exeName.dirName.dirName, "lib");
        assertExists(this.exeLibDir, "the Microsoft linker library path '%s'");
        writefln("Linker Library Path %s", this.exeLibDir.formatDir);

        //
        // sdk path
        //
        if(options.sdkPath is null)
        {
            writefln("Error: the Microsoft linker requires an sdk path");
            writeln();dumpSdks();
            throw quit;
        }
        if(!exists(options.sdkPath))
        {
            writefln("Error: the sdk path %s does not exist", options.sdkPath.formatDir);
            writeln();dumpSdks();
            throw quit;
        }
        this.sdkLibPath = buildPath(options.sdkPath, "Lib");
        if(!exists(this.sdkLibPath))
        {
            writefln("Error: sdk path %s does not exist", this.sdkLibPath.formatDir);
            writeln();dumpSdks();
            throw quit;
        }
        writefln("Sdk Library Path %s", this.sdkLibPath.formatDir);

        //
        // kit path
        //
        if(options.kitPath is null)
        {
            writefln("Error: the Microsoft linker requires a kit path");
            writeln();dumpKits();
            throw quit;
        }
        if(!exists(options.kitPath))
        {
            writefln("Error: kit path '%s' does not exist", options.kitPath.formatDir);
            writeln();dumpKits();
            throw quit;
        }
        {
            string firstKitLibEntry = null;
            foreach(entry; dirEntries(options.kitPath, "*.lib", SpanMode.breadth))
            {
                firstKitLibEntry = entry.name.idup;
                break;
            }
            if(firstKitLibEntry is null)
            {
                writefln("Error: failed to find any lib files kit path %s", options.kitPath.formatDir);
                writeln();dumpKits();
                throw quit;
            }
            this.kitLibPath = dirName(firstKitLibEntry);
            writefln("Kit Library Path %s", this.kitLibPath.formatDir);
        }
        +/
    }
    final override LinkerCall createCall()
    {
        auto call = MicrosoftLinkerInterfaceCall.create(exeName);
        //call.addLibraryPath(exeLibDir);
        //call.addLibraryPath(sdkLibPath);
        //call.addLibraryPath(kitLibPath);
        foreach(libPath; extraLibraryPaths.data)
        {
            call.addLibraryPath(libPath);
        }
        return call;
    }
}

abstract class LinkerCall
{
    abstract void run();
    abstract void setOutputFile(const(char)[] outputFile);
    abstract void addLibraryPath(const(char)[] libraryPath);
    abstract void addObjectFile(const(char)[] objectFile);
}
abstract class CommandLineLinkerCall : LinkerCall
{
    abstract const(char)[] getCommandLine();
    final override void run()
    {
        static import util;
        util.run(getCommandLine);
    }
}
class OptlinkCall : CommandLineLinkerCall
{
    static LinkerCall create(string linkerExe) { return new OptlinkCall(linkerExe); }
    string linkerExe;

    Appender!(char[]) objFiles;
    string outputFile;
    Appender!(char[]) libFiles;
    this(string linkerExe)
    {
        this.linkerExe = linkerExe;
    }
    final override const(char)[] getCommandLine()
    {
        return format("%s %s,%s,%s",
            linkerExe.formatQuotedIfSpaces,
            objFiles.data, outputFile, libFiles.data);
    }
    private static void appendFile(ref Appender!(char[]) appender, const(char)[] file)
    {
        if(appender.data.length > 0)
        {
            appender.put("+");
        }
        appender.put(file);
    }
    private static void appendDir(ref Appender!(char[]) appender, const(char)[] dir)
    {
        if(appender.data.length > 0)
        {
            appender.put("+");
        }
        appender.put(dir);
        appender.put("\\");
    }
    final override void setOutputFile(const(char)[] outputFile)
    {
        assert(!this.outputFile);
        this.outputFile = outputFile.idup;
    }
    final override void addLibraryPath(const(char)[] libraryPath)
    {
        appendDir(libFiles, libraryPath);
    }
    final override void addObjectFile(const(char)[] objectFile)
    {
        appendFile(objFiles, objectFile);
    }
}
class UnorderedCommandLineLinkerCall : CommandLineLinkerCall
{
    protected Appender!(char[]) commandLine;
    this(string linkerExe)
    {
        commandLine.putf("%s", linkerExe.formatQuotedIfSpaces);
    }
    abstract void appendOutputFile(const(char)[] outputFile);
    abstract void appendLibraryPath(const(char)[] libraryPath);
    abstract void appendObjectFile(const(char)[] objectFile);

    final override const(char)[] getCommandLine()
    {
        return commandLine.data;
    }
    final override void setOutputFile(const(char)[] outputFile)
    {
        appendOutputFile(outputFile);
    }
    final override void addLibraryPath(const(char)[] libraryPath)
    {
        appendLibraryPath(libraryPath);
    }
    final override void addObjectFile(const(char)[] objectFile)
    {
        appendObjectFile(objectFile);
    }
}
class MicrosoftLinkerInterfaceCall : UnorderedCommandLineLinkerCall
{
    static LinkerCall create(string linkerExe) { return new MicrosoftLinkerInterfaceCall(linkerExe); }
    this(string linkerExe)
    {
        super(linkerExe);
    }
    final override void appendOutputFile(const(char)[] outputFile)
    {
        commandLine.putf(" /OUT:%s", outputFile.formatQuotedIfSpaces);
    }
    final override void appendLibraryPath(const(char)[] libraryPath)
    {
        commandLine.putf(" /LIBPATH:%s", libraryPath.formatQuotedIfSpaces);
    }
    final override void appendObjectFile(const(char)[] objectFile)
    {
        commandLine.putf(" %s", objectFile.formatQuotedIfSpaces);
    }
}