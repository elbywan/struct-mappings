require "spec"
require "../src/struct-mappings"

include Mappings

lib C
  struct Structure
    string : LibC::Char*
    nested : Nested
    nested_ptr : Nested*
  end

  struct Nested
    int : LibC::Int
  end

  struct StructureArray
    data : Structure*
    size : Int32
  end

  struct StructureDblArray
    entries : Structure**
    count : Int64
  end

  struct NestedArray
    data : Nested*
    size : Int32
  end
end

struct_mapping Nested, C::Nested,
  int : Int32

struct_mapping Structure, C::Structure,
  string : String,
  nested : Nested?,
  nested_ptr : Nested? = {ptr: true}

struct_array_mapping StructureArray,
  Structure,
  C::StructureArray

struct_array_mapping StructureDblArray,
  Structure,
  C::StructureDblArray,
  data_field: entries,
  size_field: count,
  dbl_ptr: true

struct_mapping NestedWithOpts, C::Nested,
  int : Int32 = {
    # data:  the initialize function argument (named tuple)
    from_data: data["int"] + 1,
    # c_data:  the initialize function argument (c structure)
    from_c: c_data.int - 1,
    # [field name]: shortcut for @data["field name"]
    to_c: int + 1,
  }

struct_array_mapping NestedArrayWithOpts,
  Nested,
  C::NestedArray,
  # elt: an element of the array
  from_data: Nested.new({int: elt + 1}),
  from_c: Nested.new({int: elt.int - 1}),
  to_c: C::Nested.new int: elt.int + 1
