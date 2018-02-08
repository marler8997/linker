import std.typecons : Flag, Yes, No;
import std.array  : appender;
import std.string : startsWith;
import std.format : format;
import std.path   : dirName, buildPath, stripExtension, relativePath, setExtension;
import std.file   : exists, mkdir, write, remove;
import std.stdio;

import util : putf, formatRepeat, formatQuotedIfSpaces, makedirIfNotExists,
    SilentException, quit, tryRun, run;
import obj : ObjectFileFormat, dmdObjectFormats, supports;
import thelinkers : LinkerOptions, Linker, linkers, tryGetLinker, LinkerExe;

enum LinkTarget
{
    exe,
}
struct Test
{
    LinkTarget target;
    Flag!"usePhobos" usePhobos;
    string name;
    string[] filenames;
}

__gshared immutable tests = [
    //immutable Test(LinkTarget.exe, No.usePhobos, "emptymain", ["emptymain.d"]),
    immutable Test(LinkTarget.exe, Yes.usePhobos, "helloWorld", ["helloWorld.d"]),
];

__gshared string globalTestDir;
__gshared string globalTestSrcDir;
__gshared immutable(Linker)* linker;
__gshared LinkerExe linkerExe;

__gshared string dmdLibDir;
__gshared string dmdLibDirMscoff;

void usage()
{
    writeln("Usage: rdmd test.d [options] <linker>");
    writeln();
    writeln("Linkers:");
    {
        size_t maxLength = 0;
        foreach(ref linker; linkers)
        {
            if(linker.nameString.length > maxLength)
                maxLength = linker.nameString.length;
        }
        foreach(ref linker; linkers)
        {
            writefln("  %s%s(%s)", linker.nameString,
                formatRepeat(" ", 1 + maxLength - linker.nameString.length), linker.owner);
        }
    }
    writeln();
    writeln("Options:");
    writeln("  -exe    Provide the linker binary");
    writeln("  -lib    Product a library path for the linker");
    //writeln("  -sdk    Provide a path to the sdk (used for Microsoft linker)");
    //writeln("  -kit    Provide a path to the kit (used for Microsoft linker)");
}

int main(string[] args)
{
    try { return main2(args); } catch(SilentException) { return 1; }
}
int main2(string[] args)
{
    globalTestDir = dirName(__FILE_FULL_PATH__);
    globalTestDir = relativePath(globalTestDir);
    globalTestSrcDir = buildPath(globalTestDir, "src");

    args = args[1..$];

    LinkerOptions linkerOptions;
    {
        auto newArgsLength = 0;
        scope(exit) args.length = newArgsLength;
        for(size_t i = 0; i < args.length; i++)
        {
            auto arg = args[i];
            auto nextArg()
            {
                i++;
                if(i >= args.length)
                {
                    writefln("Error: the '%s' option requires an argument", arg);
                    throw quit;
                }
                return args[i];
            }
            if(arg.length == 0 || arg[0] != '-')
            {
                args[newArgsLength++] = arg;
            }
            else if(arg == "-exe")
                linkerOptions.exeName = nextArg();
            else if(arg == "-lib")
                linkerOptions.extraLibraryPaths.put(nextArg());
            //else if(arg == "-sdk")
            //    linkerOptions.sdkPath = nextArg();
            //else if(arg == "-kit")
            //    linkerOptions.kitPath = nextArg();
            else
            {
                writefln("Error: unknown option '%s'", arg);
                return 1;
            }
        }
    }
    if(args.length == 0)
    {
        usage();
        return 0;
    }
    if(args.length != 1)
    {
        writefln("Error: expected 1 command line argument but got %s", args.length);
        return 1;
    }

    auto linkerNameString = args[0];
    linker = tryGetLinker(linkerNameString);
    if(linker is null)
    {
        writefln("Error: unknown linker '%s'", linkerNameString);
        return 1;
    }
    // used to find parts of the D installation such as phobos
    linkerExe = linker.createExe(linker, linkerOptions);
    /*
    if(linkerExe is null)
    {
        linkerExe = linker.exeName;
    }
    else
    {
        if(!exists(linkerExe))
        {
            writefln("Error: linker '%s' does not exist");
            return 1;
        }
    }
    */

    // Read information about D compiler
    loadCompilerInfo();

    foreach(test; tests)
    {
        test.run();
    }
    return 0;
}
/*

enum Language
{
    D,
}
@property string extension(Language language)
{
    final switch(language)
    {
        case Language.D: return ".d";
    }
}
void compile(ref const(SourceFile) sourceFile, string sourceFilename)
{
    final switch(sourceFile.language)
    {
        case Language.D:
            run(format("dmd -c -od%s %s", dirName(sourceFilename), sourceFilename));
            break;
    }
}
*/

void loadCompilerInfo()
{
    auto compilerInfoFilename = buildPath(globalTestDir, "dmd.help");
    if(exists(compilerInfoFilename))
    {
        writefln("rm %s", compilerInfoFilename.formatQuotedIfSpaces);
        remove(compilerInfoFilename);
    }
    {
        auto compilerInfoFile = File(compilerInfoFilename, "w");
        scope(exit) compilerInfoFile.close();
        tryRun("dmd", compilerInfoFile);
    }
    if(!exists(compilerInfoFilename))
    {
        writefln("Error: failed to get help message from running dmd");
        throw quit;
    }
    string configFile = null;
    {
        auto compilerInfoFile = File(compilerInfoFilename, "r");
        scope(exit) compilerInfoFile.close();
        foreach(line; compilerInfoFile.byLine)
        {
            enum ConfigFilePrefix = "Config file: ";
            if(line.startsWith(ConfigFilePrefix))
            {
                configFile = line[ConfigFilePrefix.length .. $].idup;
                break;
            }
        }
    }
    if(configFile is null)
    {
        writefln("Error: compiler help output did not indicate where the config file was");
        throw quit;
    }
    writefln("Config file: %s", configFile);

    // HACK: for now we just assume that the 'lib' directory is relative to the config file
    dmdLibDir       = buildPath(configFile.dirName.dirName, "lib");
    dmdLibDirMscoff = buildPath(configFile.dirName.dirName, "lib32mscoff");
}

void compile(string sourceFilename, ObjectFileFormat objectFormat)
{
    auto command = appender!(char[]);
    command.put("dmd -v -c");
    version(Windows)
    {
        final switch(objectFormat)
        {
            case ObjectFileFormat.omf: break;
            case ObjectFileFormat.coff: command.put(" -m32mscoff"); break;
            case ObjectFileFormat.elf: assert(0);
        }
    }
    else static assert(0);
    command.putf(" %s", formatQuotedIfSpaces("-od", dirName(sourceFilename)));
    command.putf(" %s", sourceFilename.formatQuotedIfSpaces);
    auto infoFilename = sourceFilename ~ ".dmdout";
    auto infoFile = File(infoFilename, "w");
    scope(exit) infoFile.close();
    run(command.data, infoFile);
}

struct SourceFile
{
    string name;
    /*
    Language language;
    string text;
    */
}

void run(ref const(Test) test)
{
    /*
    foreach(objectFormat; FlagFormat!ObjectFileFormatFlag)
    {
        if(linker.objectFileFormats | objectFormat)
        {
            writefln("Running test '%s'", test.name);
        }
    }
    */
    foreach(objectFormat; dmdObjectFormats)
    {
        if(linker.objectFileFormats.supports(objectFormat))
        {
            run(test, objectFormat);
        }
    }
}
void run(ref const(Test) test, ObjectFileFormat objectFormat)
{
    writefln("Running test '%s' (object format %s)", test.name, objectFormat);

    /+
    auto testDir = buildPath(globalTestDir, test.name);
    if(!exists(testDir))
    {
        writefln("[DEBUG] mkdir \"%s\"", testDir);
        mkdir(testDir);
    }
    foreach(sourceFile; test.sourceFiles)
    {
        auto sourceFilename = buildPath(testDir, sourceFile.name ~ sourceFile.language.extension);
        if(!exists(sourceFilename))
        {
            write(sourceFilename, sourceFile.text);
        }
        sourceFile.compile(sourceFilename);
    }
    +/
    foreach(sourceFile; test.filenames)
    {
        auto relativeSourceFilename = buildPath(globalTestSrcDir, sourceFile);
        compile(relativeSourceFilename, objectFormat);
    }

    //
    // and now link
    //

    // TODO: different test directory for each linker?
    auto testDir = buildPath(globalTestDir, test.name);
    makedirIfNotExists(testDir);
    // TODO: clean the test directory?

    auto outputFile = buildPath(testDir, test.name ~ test.target.extension);

    {
        auto linkerInstance = linkerExe.createCall();
        // TODO: set objectFormat
        linkerInstance.setOutputFile(outputFile);
        if(test.usePhobos)
        {
            if(objectFormat == ObjectFileFormat.coff)
            {
                linkerInstance.addLibraryPath(dmdLibDirMscoff);
            }
            else
            {
                linkerInstance.addLibraryPath(dmdLibDir);
            }
        }
        foreach(sourceFile; test.filenames)
        {
            auto objectFile = buildPath(globalTestSrcDir, sourceFile.setExtension(objExtension));
            linkerInstance.addObjectFile(objectFile);
        }
        linkerInstance.run();
    }

    final switch(test.target)
    {
    case LinkTarget.exe:
        run(outputFile);
        break;
    }
}


version(Windows)
{
    enum objExtension = ".obj";
    enum dirSeparatorChar = "\\";
    auto extension(LinkTarget linkTarget)
    {
        final switch(linkTarget)
        {
            case LinkTarget.exe : return ".exe";
        }
    }
}
else
{
    enum objExtension = ".o";
    enum dirSeparatorChar = "/";
    auto extension(LinkTarget linkTarget)
    {
        final switch(linkTarget)
        {
            case LinkTarget.exe : return "";
        }
    }
}