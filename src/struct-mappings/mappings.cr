require "./classes.cr"
require "./utils.cr"

module Mappings
  include Mappings::Utils

  # :nodoc:
  macro base_mapping(type, skip_initialize = false, &block)
    property data : {{ type }}
    forward_missing_to @data
    delegate pretty_print, to: @data
    def_equals @data

    {% if !skip_initialize %}
      {% if block %}
        # Create a new instance from crystal space data.
        def initialize(data)
          {{ yield }}
        end
      {% else %}
        # Create a new instance from {{ type }}.
        def initialize(@data)
        end
      {% end %}
    {% end %}
  end

  # Generates a class mapping a C structure.
  #
  # #### Overview
  #
  # In practice, the created class is a wrapper around a named tuple holding the data.
  # `initialize` methods are provided for instantiating the class from a tuple or a C structure
  # and `to_unsafe` converts the data into C struct representation.
  #
  # The conversion is recursive, and will attempt to dereference structure pointers
  # which is handy in case of nested structures.
  #
  # #### Usage
  #
  # Call `struct_mapping` with:
  #
  # 1. The class name that is going to be generated.
  # 2. The mapped C structure.
  # 3. The fields that the structure contains.
  #
  # ```
  # # Include the Mappings module
  # include Mappings
  #
  # # Define a dummy structure.
  # lib C
  #   struct Data
  #     int : LibC::Int
  #   end
  # end
  #
  # # Map this structure to a crystal class.
  # struct_mapping Data, C::Data,
  #   int : Int32
  #
  # # The class can be instantiated from a named tuple containing the fields…
  # data = Data.new({int: 10})
  # # or directly from the C structure.
  # data_from_c = Data.new(
  #   C::Data.new int: 10
  # )
  # # The two classes hold the same data.
  # pp data == data_from_c # => true
  # # And it can be converted back using the `to_unsafe` method.
  # pp data.to_unsafe # => C::Data(@int=10)
  # ```
  #
  # #### Field options
  #
  # - ptr
  #
  # Use `ptr: true` to specify that the field contains a pointer to a nested structure.
  #
  # ```
  # lib C
  #   struct S
  #     # A nested structure
  #     nested : N
  #     # A pointer to a nested structure
  #     nested_ptr : N*
  #   end
  #
  #   struct N
  #     int : LibC::Int
  #   end
  # end
  #
  # struct_mapping N, C::N, int : Int32
  #
  # struct_mapping S, C::S,
  #   nested : N,
  #   # Declare this field as a pointer.
  #   nested_ptr : N = {ptr: true}
  #
  # s = S.new(C::S.new(
  #   nested: C::N.new(int: 1),
  #   nested_ptr: Pointer.malloc(sizeof(C::N), C::N.new int: 2)
  # ))
  #
  # # Both nested structures are converted into a nested named tuple.
  # pp s
  # # => {nested: {int: 1}, nested_ptr: {int: 2}}
  #
  # # Here a pointer is allocated for the nested structure.
  # pp s.to_unsafe
  # # => C::S(@nested=C::N(@int=1), @nested_ptr=Pointer(C::N)@0x10fc64f20)
  # ```
  #
  # - from_data
  #
  # Customize the behaviour when setting the internal data representation field from a tuple argument.
  #
  # - from_c
  #
  # Customize the behaviour when setting the internal data representation field from a structure argument.
  #
  # - to_c
  #
  # Customize the behaviour when setting the C structure field from the internal data representation.
  #
  # ```
  # lib C
  #   struct S
  #     field : Int32
  #   end
  # end
  #
  # struct_mapping S, C::S,
  #   # Here, the crystal representation is a String, whereas the C representation is an integer.
  #   # We are using the custom behaviour methods as adapters.
  #   field : String = {
  #     # data: the initialize function argument (named tuple)
  #     from_data: data["field"].to_s,
  #     # c_data: the initialize function argument (c structure)
  #     from_c: c_data.field.to_s,
  #     # [field name]: shortcut for @data["field name"], @data being the internal representation.
  #     to_c: field.to_i32,
  #   }
  #
  # pp S.new({field: 20})           # {field: "20"}
  # pp S.new(C::S.new field: 20)    # {field: "20"}
  # pp S.new({field: 20}).field     # "20"
  # pp S.new({field: 20}).to_unsafe # C::S(@field=20)
  # ```
  macro struct_mapping(class_name, struct_name, *args)
    class {{ class_name }} < StructMapping
      alias DataType = {
        {% for arg in args %}{{ arg.var }}: {{ arg.type }},{% end %}
      }

      {% for arg in args %}
      def {{ arg.var }}
        @data["{{arg.var}}"]
      end
      {% end %}

      Mappings.base_mapping DataType do
        @data = {
          {% for arg in args %}
            {% if arg.value && arg.value["from_data"] %}
              # Custom
              {{ arg.var }}: {{ arg.value["from_data"] }},
            {% elsif arg.type.resolve.union_types.any? { |t| t < StructMapping || t < StructArrayMapping } %}
              # Mapping
              {% if arg.type.resolve.nilable? %}
                {{ arg.var }}: data["{{ arg.var }}"].try { |v| {{ arg.type.resolve.union_types.find { |t| t != Nil } }}.new(v) },
              {% else %}
                {{ arg.var }}: {{ arg.type }}.new(data["{{arg.var}}"]),
              {% end %}
            {% else %}
              # Default
              {{ arg.var }}: data["{{arg.var}}"],
            {% end %}
          {% end %}
        }
      end

      # Create a new {{ class_name }} instance from a {{ struct_name }} structure.
      def initialize(c_data : {{ struct_name }})
          @data = {
            {% for arg in args %}
              {% if arg.value && arg.value["from_c"] %}
                # Custom
                {{ arg.var }}: {{ arg.value["from_c"] }},
              {% elsif arg.type.resolve.union_types.any? { |t| t < StructMapping || t < StructArrayMapping } %}
                {% if arg.type.resolve.nilable? %}
                  {{ arg.var }}: ({{ arg.type.resolve.union_types.find { |t| t != Nil } }}.new(c_data.{{ arg.var }}{% if arg.value && arg.value["ptr"] %}.value{% end %}) if c_data.{{ arg.var }}),
                {% else %}
                  {{ arg.var }}: {{ arg.type }}.new(c_data.{{ arg.var }}{% if arg.value && arg.value["ptr"] %}.value{% end %}),
                {% end %}
              {% elsif arg.type.resolve.union_types.includes? Bool %}
                # Core value types
                {{ arg.var }}: c_data.{{ arg.var }} == 1,
              {% elsif arg.type.resolve.union_types.includes? String %}
                # Core reference types
                {% if arg.type.resolve.nilable? %}
                  {{ arg.var }}: ptr_to_string?(c_data.{{ arg.var }}),
                {% else %}
                  {{ arg.var }}: ptr_to_string(c_data.{{ arg.var }}),
                {% end %}
              {% else %}
                # Default
                {{ arg.var }}: c_data.{{arg.var}},
              {% end %}
            {% end %}
          }
      end

      # Returns a mapped {{ struct_name }} structure suitable for use in C bindings.
      def to_unsafe
          c_data = {{ struct_name }}.new

          {% for arg in args %}
            {% if arg.value && arg.value["to_c"] %}
              # Custom
              Mappings::Utils.assign {{ arg.var }} do
                {{ arg.value["to_c"] }}
              end
            {% elsif arg.type.resolve.union_types.any? { |t| t < StructMapping || t < StructArrayMapping } && arg.value && arg.value["ptr"] %}
              # Mapping pointer
              Mappings::Utils.assign {{ arg.var }} do
                ptr_alloc({{ arg.var }}.to_unsafe)
              end
            {% elsif arg.type.resolve.union_types.includes? Bool %}
              # Core value types
              Mappings::Utils.assign_bool {{ arg.var }}
            {% else %}
              # Default
              Mappings::Utils.assign {{ arg.var }}
            {% end %}
          {% end %}

          c_data
      end
    end
  end

  # Generates a class mapping a C structure representing an array of elements.
  #
  # #### Overview
  #
  # An array representation should contain the following fields:
  # - a pointer to the first element in the array.
  # - a number, the size of the array.
  #
  # In practice, the created class is a wrapper around an Array holding the data.
  # `initialize` methods are provided for instantiating the class from an array or a C structure
  # and `to_unsafe` converts the data into a C structure representation.
  #
  # #### Usage
  #
  # Call `struct_array_mapping` with:
  #
  # 1. The class name that is going to be generated.
  # 2. The type of elements in the array.
  # 3. The mapped C structure.
  # 4. Additional arguements.
  #
  # ```
  # # Include the Mappings module
  # include Mappings
  #
  # # Define dummy structures.
  # lib C
  #   struct Data
  #     int : LibC::Int
  #   end
  #
  #   struct DataArray
  #     data : Data*
  #     size : Int32
  #   end
  # end
  #
  # # Map the structure to a crystal class.
  # struct_mapping Data, C::Data,
  #   int : Int32
  #
  # # Map the array structure to a crystal class.
  # struct_array_mapping DataArray, Data, C::DataArray
  #
  # # The class can be instantiated from an array of crystal classes…
  # data_array = DataArray.new [
  #   Data.new({int: 10}),
  #   Data.new({int: 20}),
  # ]
  # # or directly from the C structure.
  # data_array_from_c = DataArray.new C::DataArray.new(
  #   size: 2,
  #   data: [
  #     C::Data.new(int: 10),
  #     C::Data.new(int: 20),
  #   ]
  # )
  #
  # # The two classes hold the same data.
  # pp data_array == data_array_from_c # => true
  # # And it can be converted back using the `to_unsafe` method.
  # pp data_array.to_unsafe
  # # => C::DataArray(
  # #      @data=Pointer(C::Data)@0x1052c5e10,
  # #      @size=2)
  # ```
  #
  # #### Additional arguments
  #
  # - dbl_ptr (default: false)
  #
  # Set `dbl_ptr` to true if the c structure represents an array of structure pointers.
  #
  # - size_field (default: size)
  #
  # Used to identify the structure field name that contains the size of the array.
  #
  # - data_field (default: data)
  #
  # Used to identify the structure field name that contains the array pointer.
  #
  # - from_data
  #
  # Customize the behaviour when setting the internal data representation field from a crystal array.
  #
  # - from_c
  #
  # Customize the behaviour when setting the internal data representation field from a structure argument.
  #
  # - to_c
  #
  # Customize the behaviour when setting the C structure field from the internal data representation.
  #
  # ```
  # lib C
  #   struct S
  #     field : Int32
  #   end
  #
  #   struct SArray
  #     data : S*
  #     size : LibC::Int
  #   end
  # end
  #
  # struct_mapping S, C::S, field : Int32
  # # Let's change the default beaviour using the `from_data`, `to_data` and `to_c` functions.
  # # For all these methods, `elt` is an element of the source array.
  # struct_array_mapping SArray, S, C::SArray,
  #   # Here, we allow an SArray to be initialized with a plain array of integers.
  #   from_data: S.new({field: elt}),
  #   # Here, we substract one when initializing from a C structure.
  #   from_c: S.new({field: elt.field - 1}),
  #   # And we add one when converting into a C structure.
  #   to_c: C::S.new field: elt.field + 1
  #
  # pp SArray.new [0, 1, 2]
  # # => [{field: 0}, {field: 1}, {field: 2}]
  # pp SArray.new(
  #   C::SArray.new size: 3, data: [
  #     C::S.new(field: 1),
  #     C::S.new(field: 2),
  #     C::S.new(field: 3),
  #   ].to_unsafe
  # )
  # # => [{field: 0}, {field: 1}, {field: 2}]
  # pp SArray.new([0, 1, 2]).to_unsafe
  # # => C::SArray(@data=Pointer(C::S)@0x108cbfd60, @size=3)
  # ```
  macro struct_array_mapping(
    class_name,
    of_class,
    struct_name,
    dbl_ptr = false,
    from_data = nil,
    from_c = nil,
    to_c = nil,
    size_field = size,
    data_field = data,
    size_type = nil
  )
    class {{ class_name }} < StructArrayMapping
    Mappings.base_mapping Array({{ of_class }}) do
        {% if from_data %}
          @data = data.map do |elt|
            {{ from_data }}
          end
        {% else %}
          @data = data.map do |elt|
            {{ of_class }}.new elt
          end
        {% end %}
      end

      # Create a new {{ class_name }} instance from a {{ struct_name }} structure.
      def initialize(c_data : {{ struct_name }})
        size = c_data.{{ size_field }}
        @data = Array({{ of_class }}).new(
          size || 0
        )
        if c_data.{{ data_field }}
          (0...size).each do |i|
            elt = c_data.{{ data_field }}[i]
            %to_push = (
              {% if from_c %}{{ from_c }}{% elsif dbl_ptr %}{{ of_class }}.new elt.value{% else %}{{ of_class }}.new elt{% end %}
            )
            @data << %to_push
          end
        else
          @data = [] of {{ of_class }}
        end
      end

      # Returns a mapped {{ struct_name }} structure suitable for use in C bindings.
      def to_unsafe
        {{ struct_name }}.new(
          {{ data_field }}: @data.map do |elt|
            {% if to_c %}
              {{ to_c }}
            {% elsif dbl_ptr %}
              ptr_alloc elt.to_unsafe
            {% else %}
              elt.to_unsafe
            {% end %}
          end,
          {{ size_field }}: {% if size_type %}{{ size_type }}.new {% end %}@data.size
        )
      end
    end
  end
end
