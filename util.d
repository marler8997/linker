module util;

pragma(inline) auto ref staticCast(T,F)(auto ref F from)
{
    return *cast(T*)cast(void*)&from;
}


struct Vector(T)
{
    private T[] array;
    void put(T newItem)
    {
        array ~= newItem;
    }
}

struct StringRef
{

}

struct Pair(T,S)
{
    T first;
    S second;
}