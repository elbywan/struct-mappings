# :nodoc:
module Mappings::Utils
  # :nodoc:
  macro ptr_to_string?(id)
    (String.new({{id}}.as(UInt8*)) if {{id}})
  end

  # :nodoc:
  macro ptr_to_string(id)
    String.new({{id}}.as(UInt8*))
  end

  # :nodoc:
  macro assign(id, &block)
    if {{id}} = @data["{{id}}"]
      {% if block %}
        c_data.{{id}} = {{ block.body }}
      {% else %}
        c_data.{{id}} = {{id}}
      {% end %}
    end
  end

  # :nodoc:
  macro assign_bool(id)
    Mappings::Utils.assign {{id}} do
      @data["{{id}}"] ? 1_i8 : 0_i8
    end
  end

  # :nodoc:
  macro ptr_of(exp)
    %temp = {{ exp }}
    %temp ? pointerof(%temp) : Pointer(typeof(%temp)).null
  end

  # :nodoc:
  macro ptr_alloc(exp)
    %temp = {{ exp }}
    %temp ? Pointer.malloc(size: sizeof(typeof(%temp)), value: %temp) : Pointer(typeof(%temp)).null
  end
end
