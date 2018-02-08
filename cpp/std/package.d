module cpp.std;

public import cpp.dthunk;
public import cpp.std.system_error;


import std.typecons : Unique;

struct char_traits(CharT)
{
    alias char_type = CharT;
}

struct allocator(CharT)
{
    //enum 
}
class basic_string(CharT, Traits = char_traits!CharT, Allocator = allocator!CharT)
{
    alias traits_type = Traits;
    alias value_type = Traits.char_type;
    alias allocator_type = Allocator;

    //private alias CharTAllocType = typeof(Allocator.rebind!CharT.other);
    //alias size_type        = CharTAllocType.size_type;
    //alias difference_type  = CharTAllocType.difference_type;
    //alias reference        = CharTAllocType.reference;
    //alias const_reference  = CharTAllocType.const_reference;
    //alias pointer          = CharTAllocType.pointer;
    //alias const_pointer    = CharTAllocType.const_pointer;
    //alias iterator         = typedef __gnu_cxx::__normal_iterator<pointer, basic_string>  ;
    //alias const_iterator   = typedef __gnu_cxx::__normal_iterator<const_pointer, basic_string>;
    //alias const_reverse_iterator = typedef std::reverse_iterator<const_iterator>	;
    //alias reverse_iterator = typedef std::reverse_iterator<iterator>		    ;
}

alias string = Value!(basic_string!char);
alias wstring = Value!(basic_string!wchar);

// Note: Unique is not the same a unique_ptr, will need to check usage of this on a case by case basis
alias unique_ptr = Unique;

struct ArrayRef(T)
{

}

struct vector(T)
{
    
}