require "./spec_helper"

describe Mappings do
  context "struct_mapping" do
    it "should properly map c structures" do
      data = {
        string: "a string",
        nested: {
          int: 10,
        },
        nested_ptr: nil,
      }

      c_struct = C::Structure.new(
        string: "a string",
        nested: C::Nested.new(
          int: 10
        ),
        nested_ptr: nil
      )

      from_data = Structure.new data
      from_c = Structure.new c_struct
      from_c.should eq from_data

      from_data.to_unsafe.should eq c_struct
    end

    it "should properly map nested c structures pointers" do
      data = {
        string: "a string",
        nested: {
          int: 0,
        },
        nested_ptr: {
          int: 20,
        },
      }

      c_struct = C::Structure.new(
        string: "a string",
        nested: C::Nested.new(int: 0),
        nested_ptr: Pointer.malloc sizeof(C::Nested), C::Nested.new(
          int: 20
        )
      )

      from_data = Structure.new data
      from_c = Structure.new c_struct
      from_c.should eq from_data

      from_data.to_unsafe.string.should eq c_struct.string
      from_data.to_unsafe.nested.should eq c_struct.nested
      from_data.to_unsafe.nested_ptr.value.should eq c_struct.nested_ptr.value
    end

    it "should allow custom behaviour" do
      data = {int: 1}
      c_struct = C::Nested.new int: 3

      from_data = NestedWithOpts.new data
      from_c = NestedWithOpts.new c_struct
      from_c.should eq from_data
      from_data.to_unsafe.should eq c_struct
    end
  end

  context "struct_array_mapping" do
    it "should map arrays of c structures" do
      data = {
        string: "a string",
        nested: {
          int: 0,
        },
        nested_ptr: {
          int: 20,
        },
      }

      c_struct = C::Structure.new(
        string: "a string",
        nested: C::Nested.new(int: 0),
        nested_ptr: Pointer.malloc sizeof(C::Nested), C::Nested.new(
          int: 20
        )
      )

      c_struct_arr = C::StructureArray.new(
        data: [c_struct, c_struct],
        size: 2
      )

      arr_from_data = StructureArray.new [data, data]
      arr_from_c = StructureArray.new c_struct_arr
      arr_from_data.should eq arr_from_c

      unsafe_struct = arr_from_data.to_unsafe.data.value

      arr_from_data.to_unsafe.size.should eq 2
      unsafe_struct.string.should eq c_struct.string
      unsafe_struct.nested.should eq c_struct.nested
      unsafe_struct.nested_ptr.value.should eq c_struct.nested_ptr.value
    end

    it "should map double arrays of c structures" do
      data = {
        string: "a string",
        nested: {
          int: 0,
        },
        nested_ptr: {
          int: 20,
        },
      }

      c_struct = C::Structure.new(
        string: "a string",
        nested: C::Nested.new(int: 0),
        nested_ptr: Pointer.malloc sizeof(C::Nested), C::Nested.new(
          int: 20
        )
      )

      c_struct_arr = C::StructureDblArray.new(
        entries: Pointer.malloc(sizeof(C::Structure*), [c_struct, c_struct].to_unsafe),
        count: 2
      )

      arr_from_data = StructureDblArray.new [data, data]
      arr_from_c = StructureDblArray.new c_struct_arr
      arr_from_data.should eq arr_from_c

      unsafe_struct = arr_from_data.to_unsafe.entries.value.value

      arr_from_data.to_unsafe.count.should eq 2
      unsafe_struct.string.should eq c_struct.string
      unsafe_struct.nested.should eq c_struct.nested
      unsafe_struct.nested_ptr.value.should eq c_struct.nested_ptr.value
    end

    it "should allow custom behaviour" do
      c_data = C::NestedArray.new(
        size: 2,
        data: [
          C::Nested.new(int: 2),
          C::Nested.new(int: 3),
        ].to_unsafe
      )

      from_data = NestedArrayWithOpts.new [0, 1]
      from_c = NestedArrayWithOpts.new c_data
      from_data.should eq from_c

      from_data.to_unsafe.size.should eq c_data.size
      (0...from_data.to_unsafe.size).each do |i|
        from_data.to_unsafe.data[i].should eq c_data.data[i]
      end
    end
  end
end
