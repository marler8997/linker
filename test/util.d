module util;

import std.stdio;

struct FlagRange(T)
{
    T next;
    this()
    {
        next = cast(T)1;
    }
    @property bool empty() { next == 0; }
    @proprty T front() { return next; }
    void popFront()
    {
        next <<= 1;
        if(next > T.max)
        {
            next = 0;
        }
    }
}

alias StringSink = scope void delegate(const(char)[]);

auto formatRepeat(T)(T obj, size_t repeatCount)
{
    static struct Formatter
    {
        T obj;
        size_t repeatCount;
        void toString(StringSink sink)
        {
            foreach(i; 0..repeatCount)
            {
                static if(__traits(compiles, sink(obj)))
                {
                    sink(obj);
                }
                else
                {
                    obj.toString(sink);
                }
            }
        }
    }
    return Formatter(obj, repeatCount);
}

/**
Append a formatted string into a character OutputRange
*/
void putf(R, U...)(auto ref R outputRange, string fmt, U args)
{
    import std.format : formattedWrite;
    formattedWrite(&outputRange.put!(const(char)[]), fmt, args);
}

// returns a formatter that will print the given string.  it will print
// it surrounded with quotes if the string contains any spaces.
@property auto formatQuotedIfSpaces(T...)(T args) if(T.length > 0)
{
    struct Formatter
    {
        T args;
        void toString(scope void delegate(const(char)[]) sink) const
        {
            bool useQuotes = false;
            foreach(arg; args)
            {
                import std.string : indexOf;
                if(arg.indexOf(' ') >= 0)
                {
                    useQuotes = true;
                    break;
                }
            }

            if(useQuotes)
            {
                sink("\"");
            }
            foreach(arg; args)
            {
                sink(arg);
            }
            if(useQuotes)
            {
                sink("\"");
            }
        }
    }
    return Formatter(args);
}

@property auto formatDir(const(char)[] dir)
{
    if(dir.length == 0)
    {
        dir = ".";
    }
    return formatQuotedIfSpaces(dir);
}

void makedirIfNotExists(const(char)[] dir)
{
    import std.file : exists, mkdir;
    if(!exists(dir))
    {
        import std.stdio : writefln;
        writefln("mkdir \"%s\"", dir);
        mkdir(dir);
    }
}

class SilentException : Exception { this() { super(null); }}
auto quit() { return new SilentException(); }

auto tryRun(const(char)[] command, File stdout = std.stdio.stdout)
{
    import std.process : spawnShell, wait;

    if(stdout is std.stdio.stdout)
    {
        writefln("[SHELL] %s", command);
    }
    else
    {
        writefln("[SHELL] %s > %s", command, stdout.name);
    }
    auto pid = spawnShell(command, std.stdio.stdin, stdout);
    auto exitCode = wait(pid);
    writeln("-------------------------------------------------------");
    return exitCode;
}
void run(const(char)[] command, File stdout = std.stdio.stdout)
{
    auto exitCode = tryRun(command, stdout);
    if(exitCode)
    {
        writefln("failed with exit code %s", exitCode);
        throw quit;
    }
}