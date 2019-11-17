# struct-mappings

#### Generate crystal classes mapping C structures.

[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://elbywan.github.io/struct-mappings/)
[![GitHub release](https://img.shields.io/github/release/elbywan/struct-mappings.svg)](https://github.com/elbywan/struct-mappings/releases)
[![Build Status](https://travis-ci.org/elbywan/struct-mappings.svg?branch=master)](https://travis-ci.org/elbywan/struct-mappings)

## Purpose

`struct-mappings` exposes useful macros that can be used to convert a [C struct](https://crystal-lang.org/reference/syntax_and_semantics/c_bindings/struct.html) into a Crystal class and vice versa.

The inner representation of the data is a [NamedTuple](https://crystal-lang.org/api/latest/NamedTuple.html) which is very convenient to use.

## Utility

Conversion from & to a C structure could be useful in the following scenarios:

- Persisting data that would get freed otherwise when calling an external library.
- Avoiding calling `.value` on nested structure pointers.
- C structs are arguably less convenient to use compared to named tuples.

## Features

- Supports nested structures.
- Automatically allocates & dereference structure pointers.
- C structures containing array pointers can be converted to an array wrapper class.
- Conversion can be customized.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     struct-mappings:
       github: elbywan/struct-mappings
   ```

2. Run `shards install`

## Usage

#### Require

```crystal
require "struct-mappings"
```

#### Minimal use case

```crystal
# Include the Mappings module
include Mappings

# Define a dummy structure.
lib C
  struct Data
    int: LibC::Int
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
    data: Data*
    size: LibC::Int
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
```

## Documentation

The exhaustive documentation is hosted [here](https://elbywan.github.io/struct-mappings).

## Contributing

1. Fork it (<https://github.com/your-github-user/struct-mappings/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [elbywan](https://github.com/your-github-user) - creator and maintainer
