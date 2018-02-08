/**
Helper code to allow D to emulate some C++ specific semantics
*/
module cpp.dthunk;

// TODO: not sure if these type alias's are correct
alias c_int = int;

/**
Value is a template that represents a class object value.  This is in contrast to a
normal class object which is a pointer to a class object value.

---
void foo(Value!SomeClass value)
{
    // ... use value
}
---

TODO: this implementation current ignore any class alignment requirments.
      referece the "scoped" temlpate in in std.typecons for details
*/
struct Value(T) if( is( T == class ) )
{
    @disable this();
    private void[__traits(classInstanceSize, T)] ____classdata = void;
    @property pragma(inline) T classptr() { return cast(T)&this; }
    alias classptr this;
}
/**
Initializes a class value
*/
void initClassValue(T, Args...)(Value!T* classValue, Args args) if( is( T == class ) )
{
    import std.conv : emplace;
    emplace(classValue.classptr, args);
}
/**
Use to create a class object value.
---
auto classValue = createClasValue!SomeClass;
---
*/
Value!T createClassValue(T, Args...)(Args args) if( is( T == class ) )
{
    import std.conv : emplace;
    Value!T value = void;
    emplace(value.classptr, args);
    return value;
}

/**
Creates a Value!T class from class T.
---
Foo foo; // foo is a class

Value!Foo fooValue1 = void;
copyClassValue(&fooValue1, classObject);

auto foo2 = foo.copyClassValue();
---
*/
void copyClassValue(T)(Value!T* classValue, T classObject) if( is( T == class ) )
{
    classValue.____classdata[0..__traits(classInstanceSize, T)] =
        (cast(ubyte*)classObject)[0..__traits(classInstanceSize, T)];
}
/// ditto
Value!T copyClassValue(T)(T classObject) if( is( T == class ) )
{
    Value!T value = void;
    copyClassValue(&value, classObject);
    return value;
}

unittest
{
    static class Foo
    {
        int x;
        this(int x) { this.x = x; }
        void assertValue(int expected)
        {
            assert(x == expected);
        }
        void doNothing() { }
    }
    static void testValueClassArg(Value!Foo foo, int valueToAssert)
    {
        foo.assertValue(valueToAssert);
    }
    {
        auto foo = createClassValue!Foo(946);
        assert(foo.x == 946);
        foo.assertValue(946);
        testValueClassArg(foo, 946);

        initClassValue(&foo, 391);
        assert(foo.x == 391);
        foo.assertValue(391);
        testValueClassArg(foo, 391);
    }
    {
        auto foo = new Foo(1234);
        assert(foo.x == 1234);
        foo.assertValue(1234);

        Value!Foo fooValue = void;
        copyClassValue(&fooValue, foo);
        assert(fooValue.x == 1234);
        fooValue.assertValue(1234);
        testValueClassArg(fooValue, 1234);

        auto fooValue2 = foo.copyClassValue();
        assert(fooValue2.x == 1234);
        fooValue2.assertValue(1234);
        testValueClassArg(fooValue2, 1234);

        testValueClassArg(foo.copyClassValue(), 1234);
    }
}