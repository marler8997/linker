import std.path : buildPath;
import std.file : exists, dirEntries, SpanMode;
import std.stdio;

import util : formatQuotedIfSpaces, formatDir;

/*
The Visual C++ command-line tools use the PATH, TMP, INCLUDE, LIB, and LIBPATH 
*/

int main(string[] args)
{
    enum ProgramFiles = `C:\Program Files (x86)`;

    foreach(entry; dirEntries(ProgramFiles, "Microsoft Visual Studio *", SpanMode.shallow))
    {
        scanVisualStudio(entry.name);
    }

    return 0;
}

void scanVisualStudio(const(char)[] visualStudio)
{
    // Check if Visual C is installed for this visual studio
    writeln("-----------------------------------------------------------");
    writefln("Scanning %s", visualStudio.formatDir);
    
    auto vcPath = buildPath(visualStudio, "VC");
    if(!exists(vcPath))
    {
        writefln("  Visual C not installed (%s does not exist)", vcPath.formatDir);
        return;
    }
    auto vcvarsallFilename = buildPath(vcPath, "vcvarsall.bat");
    if(!exists(vcvarsallFilename))
    {
        writefln("  Visual C not installed (%s does not exist)", vcvarsallFilename.formatQuotedIfSpaces);
        return;
    }

    writefln("Searching for vcvars<option>.bat scripts...");
    auto binPath = buildPath(vcPath, "bin");
    if(!exists(binPath))
    {
        writefln("WARNING: path '%s' does not exist, this version of visual studio might use a different mechanism to setup developer command line environments",
            binPath.formatDir);
        return;
    }

    foreach(entry; dirEntries(binPath, "vcvars*.bat", SpanMode.shallow))
    {
        writefln("  %s", entry.name.formatQuotedIfSpaces);
    }
    // search for vcvars options
    

}
