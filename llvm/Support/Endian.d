module llvm.Support.Endian;


struct packed_endian_specific_integral(value_type, endianness endian, size_t alignment)
{
    // TODO: somehow specify alignment
    /*
  private AlignedCharArray<PickAlignment<value_type, alignment>::value,
                   sizeof(value_type)> Value;
    */
    union
    {
        ubyte[value_type.sizeof] bytes;

    }

    /*
    struct ref
    {
        explicit ref(void *Ptr) : Ptr(Ptr) {}

        operator value_type() const {
        return endian::read<value_type, endian, alignment>(Ptr);
        }

        void operator=(value_type NewValue) {
        endian::write<value_type, endian, alignment>(Ptr, NewValue);
        }

        private void *Ptr;
    }
    */

  //packed_endian_specific_integral() = default;

  this(value_type val) { *this = val; }

/+
  @property auto value_type() const {
    return endian.read<value_type, endian, alignment>(
      (const void*)Value.buffer);
  }

  void operator=(value_type newValue) {
    endian.write<value_type, endian, alignment>(
      (void*)Value.buffer, newValue);
  }

  packed_endian_specific_integral &operator+=(value_type newValue) {
    *this = *this + newValue;
    return *this;
  }

  packed_endian_specific_integral &operator-=(value_type newValue) {
    *this = *this - newValue;
    return *this;
  }

  packed_endian_specific_integral &operator|=(value_type newValue) {
    *this = *this | newValue;
    return *this;
  }

  packed_endian_specific_integral &operator&=(value_type newValue) {
    *this = *this & newValue;
    return *this;
  }
  +/
}


alias ulittle16_t =
    detail::packed_endian_specific_integral<uint16_t, little, unaligned>;
