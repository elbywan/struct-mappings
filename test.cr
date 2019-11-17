require "./src/struct-mappings"

# Include the Mappings module
include Mappings

# Define a dummy structure.
lib C
  struct Data
    int : LibC::Int
  end
end

# Map this structure to a crystal class.
struct_mapping Data, C::Data,
  int : Int32

# The class can be instantiated from a named tuple containing the fields…
data = Data.new({int: 10})
# or directly from the C structure.
data_from_c = Data.new(
  C::Data.new int: 10
)
# The two classes hold the same data.
pp data == data_from_c # => true
# And it can be converted back using the `to_unsafe` method.
pp data.to_unsafe # => C::Data(@int=10)

# For structures that represent arrays, it's also quite simple.

# Define a dummy array.

lib C
  struct DataArray
    data : Data*
    size : LibC::Int
  end
end

# Map the array to a crystal class.
# Generates a `DataArray` class which is a wrapper around
# an Array of `Data` classes, and mapping the `C::DataArray` struct.
struct_array_mapping DataArray, Data, C::DataArray

# Can be instantiated from a crystal array…
array_from_data = DataArray.new [
  Data.new({int: 10}),
  Data.new({int: 20}),
]
pp array_from_data # => [{int: 10}, {int: 20}]

# or a C structure representation.
array_from_c = DataArray.new C::DataArray.new(
  size: 2,
  data: [
    C::Data.new(int: 10),
    C::Data.new(int: 20),
  ].to_unsafe
)
pp array_from_c # => [{int: 10}, {int: 20}]

# The two classes hold the same data.
pp array_from_data == array_from_c # => true

# And it can be converted back using the `to_unsafe` method.
pp array_from_data.to_unsafe # => C::DataArray(@data=Pointer(C::Data)@0x10e1cfda0, @size=2)
