module cpp.std.system_error;

import std.typecons : Rebindable;
import cpp.dthunk;

struct errc
{
    private c_int value;
    @property c_int asInt() const nothrow { return value; }
}

/// error_category
abstract class error_category
{
    //public:
    //constexpr error_category() noexcept = default;

    //virtual ~error_category();

    //error_category(const error_category&) = delete;
    //disables copy
    //?

    //error_category& operator=(const error_category&) = delete;
    //disables assignment
    //?

    //virtual const char* name() const noexcept = 0;
    abstract string name() const nothrow;

    // We need two different virtual functions here, one returning a
    // COW string and one returning an SSO string. Their positions in the
    // vtable must be consistent for dynamic dispatch to work, but which one
    // the name "message()" finds depends on which ABI the caller is using.
    /*
    #if _GLIBCXX_USE_CXX11_ABI
    private:
    _GLIBCXX_DEFAULT_ABI_TAG
    virtual __cow_string _M_message(int) const;

    public:
    _GLIBCXX_DEFAULT_ABI_TAG
    virtual string message(int) const = 0;
    #else
    virtual string message(int) const = 0;

    private:
    virtual __sso_string _M_message(int) const;
    #endif
    */
    abstract string message(c_int) const;

    //public:
    //virtual error_condition default_error_condition(int __i) const noexcept;
    error_condition default_error_condition(c_int __i) const nothrow
    { return error_condition(__i, this); }

    //virtual bool equivalent(int __i, const error_condition& __cond) const noexcept;
    bool equivalent(c_int __i, const(error_condition) __cond) const nothrow
    { return default_error_condition(__i) == __cond; }

    //virtual bool equivalent(const error_code& __code, int __i) const noexcept;
    bool equivalent(ref const(error_code) __code, c_int __i) const nothrow
    {
        return this.cppOpEquals(__code.category()) &&__code.value() == __i;
    }

    //bool operator<(const error_category& __other) const noexcept
    //{ return less<const error_category*>()(this, &__other); }

    //bool operator==(const error_category& __other) const noexcept
    //{ return this == &__other; }
    bool cppOpEquals(const(error_category) __other) const nothrow
    {
        return this.cppOpEquals(__other);
    }

    //bool operator!=(const error_category& __other) const noexcept
    //{ return this != &__other; }
};

// DR 890.
//_GLIBCXX_CONST const error_category& system_category() noexcept;
const(error_category) system_category() nothrow
{ return system_category_class.instance; }
private class system_category_class : error_category
{
    __gshared static Value!system_category_class instance = void;
    static this()
    {
        initClassValue!system_category_class(&instance);
    }
    private this() { }
    final override string name() const nothrow { return "system"; }
    final override string message(c_int) const { return "system_category.message not implemented"; }
}

//_GLIBCXX_CONST const error_category& generic_category() noexcept;
const(error_category) generic_category() nothrow
{ return generic_category_class.instance; }
private class generic_category_class : error_category
{
    __gshared static Value!generic_category_class instance = void;
    static this()
    {
        initClassValue!generic_category_class(&instance);
    }
    private this() { }
    final override string name() const nothrow { return "generic"; }
    final override string message(c_int) const { return "generic_category.message not implemented"; }
}

/// error_code
// Implementation-specific error identification
struct error_code
{
    //error_code() noexcept : _M_value(0), _M_cat(&system_category()) { }
    //this() nothrow { _M_cat = &system_category(); }

    //error_code(int __v, const error_category& __cat) noexcept
    //: _M_value(__v), _M_cat(&__cat) { }
    this(c_int __v, const(error_category) __cat) nothrow
    { _M_value = __v; _M_cat = __cat; }

    //template<typename _ErrorCodeEnum, typename = typename
    //enable_if<is_error_code_enum<_ErrorCodeEnum>::value>::type>
    //error_code(_ErrorCodeEnum __e) noexcept
    //{ *this = make_error_code(__e); }


    //void assign(int __v, const error_category& __cat) noexcept
    //{
    //    _M_value = __v;
    //    _M_cat = &__cat; 
    //}
    final void assign(c_int __v, const(error_category) __cat) nothrow
    {
        _M_value = __v;
        _M_cat   = __cat;
    }

    //void clear() noexcept { assign(0, system_category()); }
    final void clear() nothrow { assign(0, system_category()); }

    // DR 804.
    //template<typename _ErrorCodeEnum>
    //typename enable_if<is_error_code_enum<_ErrorCodeEnum>::value,
    //error_code&>::type
    //operator=(_ErrorCodeEnum __e) noexcept
    //{ return *this = make_error_code(__e); }

    //int value() const noexcept { return _M_value; }
    c_int value() const nothrow { return _M_value; }

    //const error_category& category() const noexcept { return *_M_cat; }
    const(error_category) category() const nothrow { return _M_cat; }

    //error_condition default_error_condition() const noexcept;
    error_condition default_error_condition() const nothrow
    { return category().default_error_condition(value()); }

    //_GLIBCXX_DEFAULT_ABI_TAG
    //string  message() const { return category().message(value()); }
    string message() const { return category.message(value()); }

    //explicit operator bool() const noexcept { return _M_value != 0 ? true : false; }
    bool opCast(T)()
    {
        static assert( is(T == bool) , "cannot cast error_code to " ~ T.stringof);
        return _M_value != 0 ? true : false;
    }

    // DR 804.
    private:
    //friend class hash<error_code>;

    //int                   _M_value;
    c_int                   _M_value;
    //const error_category* _M_cat;
    Rebindable!(const(error_category))   _M_cat;
};

// 19.4.2.6 non-member functions
//inline error_code make_error_code(errc __e) noexcept
//{ return error_code(static_cast<int>(__e), generic_category()); }
pragma(inline) error_code make_error_code(errc __e) nothrow
{ return error_code(__e.asInt, generic_category()); }


//error_condition make_error_condition(errc) noexcept;

/// error_condition
// Portable error identification
struct error_condition 
{
    //error_condition() noexcept
    //: _M_value(0), _M_cat(&generic_category()) { }

    //error_condition(int __v, const error_category& __cat) noexcept
    //: _M_value(__v), _M_cat(&__cat) { }
    this(c_int __v, const(error_category) __cat) nothrow
    { _M_value = __v; _M_cat = __cat; }

    //template<typename _ErrorConditionEnum, typename = typename
    //enable_if<is_error_condition_enum<_ErrorConditionEnum>::value>::type>
    //error_condition(_ErrorConditionEnum __e) noexcept
    //{ *this = make_error_condition(__e); }

    //void assign(int __v, const error_category& __cat) noexcept
    //{ _M_value = __v; _M_cat = &__cat; }
    final void assign(c_int __v, const(error_category) __cat) nothrow
    { _M_value = __v; _M_cat = __cat; }

    // DR 804.
    //template<typename _ErrorConditionEnum>
    //typename enable_if<is_error_condition_enum
    //<_ErrorConditionEnum>::value, error_condition&>::type
    //operator=(_ErrorConditionEnum __e) noexcept
    //{ return *this = make_error_condition(__e); }

    //void clear() noexcept { assign(0, generic_category()); }
    final void clear() nothrow { assign(0, generic_category()); }

    // 19.4.3.4 observers
    //int value() const noexcept { return _M_value; }
    final int value() const nothrow { return _M_value; }

    //const error_category& category() const noexcept { return *_M_cat; }
    final const(error_category) category() const nothrow { return _M_cat; }

    //_GLIBCXX_DEFAULT_ABI_TAG
    //string message() const { return category().message(value()); }
    final string message() const { return category().message(value()); }

    //explicit operator bool() const noexcept
    //{ return _M_value != 0 ? true : false; }
    final bool opCast(T)()
    {
        static assert( is(T == bool) , "cannot cast error_condition to " ~ T.stringof);
        return _M_value != 0 ? true : false;
    }

    // DR 804.
    private:
    //int                   _M_value;
    c_int                   _M_value;
    //const error_category* _M_cat;
    Rebindable!(const(error_category))   _M_cat;
};

// 19.4.3.6 non-member functions
//inline error_condition make_error_condition(errc __e) noexcept
//{ return error_condition(static_cast<int>(__e), generic_category()); }
pragma(inline) error_condition make_error_condition(errc __e) nothrow
{ return error_condition(__e.asInt, generic_category()); }

/+
inline bool operator<(const error_condition& __lhs,
const error_condition& __rhs) noexcept
{
    retu    rn (__lhs.category() < __rhs.category()
    || (__lhs.category() == __rhs.category()
    && __lhs.value() < __rhs.value()));
}

// 19.4.4 Comparison operators
inline bool operator==(const error_code& __lhs, const error_code& __rhs) noexcept
{ return (__lhs.category() == __rhs.category()
&& __lhs.value() == __rhs.value()); }

inline bool operator==(const error_code& __lhs, const error_condition& __rhs) noexcept
{
    return (__lhs.category().equivalent(__lhs.value(), __rhs)
        || __rhs.category().equivalent(__lhs, __rhs.value()));
}

inline bool operator==(const error_condition& __lhs, const error_code& __rhs) noexcept
{
    return (__rhs.category().equivalent(__rhs.value(), __lhs)
    || __lhs.category().equivalent(__rhs, __lhs.value()));
}

inline bool operator==(const error_condition& __lhs,
const error_condition& __rhs) noexcept
{
    return (__lhs.category() == __rhs.category()
    && __lhs.value() == __rhs.value());
}

inline bool operator!=(const error_code& __lhs, const error_code& __rhs) noexcept
{ return !(__lhs == __rhs); }

inline bool operator!=(const error_code& __lhs, const error_condition& __rhs) noexcept
{ return !(__lhs == __rhs); }

inline bool operator!=(const error_condition& __lhs, const error_code& __rhs) noexcept
{ return !(__lhs == __rhs); }

inline bool operator!=(const error_condition& __lhs,
const error_condition& __rhs) noexcept
{ return !(__lhs == __rhs); }

+/
