defmodule JsonTypedef do
  @types MapSet.new([
           "boolean",
           "float32",
           "float64",
           "int8",
           "uint8",
           "int16",
           "uint16",
           "int32",
           "uint32",
           "string",
           "timestamp"
         ])

  alias JsonTypedef.ErrorPath

  def validate(schema, data) do
    errors = do_validate(schema, data, [], [], schema)
    if errors == [], do: {:ok, true}, else: {:error, errors}
  end

  defp do_validate(%{"nullable" => true}, nil, _ip, _sp, _root), do: []

  defp do_validate(%{"ref" => ref, "definitions" => defs} = schema, data, ip, sp, root) do
    case Map.fetch(defs, ref) do
      {:ok, ref_schema} ->
        merged_schema = Map.merge(ref_schema, Map.drop(schema, ["ref", "definitions"]))

        do_validate(
          merged_schema,
          data,
          ip,
          sp ++ ["definitions", ref],
          root
        )

      :error ->
        [
          %ErrorPath{
            instance_path: ip,
            schema_path: sp ++ ["definitions", ref]
          }
        ]
    end
  end

  defp do_validate(%{"type" => type} = schema, data, ip, sp, _root) do
    cond do
      schema["nullable"] && is_nil(data) ->
        []

      type_valid?(type, data) ->
        []

      true ->
        [
          %ErrorPath{
            instance_path: ip,
            schema_path: sp ++ ["type"]
          }
        ]
    end
  end

  defp do_validate(%{"enum" => values} = schema, data, ip, sp, _root) do
    cond do
      schema["nullable"] && is_nil(data) ->
        []

      data in values ->
        []

      true ->
        [
          %ErrorPath{
            instance_path: ip,
            schema_path: sp ++ ["enum"]
          }
        ]
    end
  end

  defp do_validate(%{"elements" => elem_schema} = schema, data, ip, sp, root) do
    cond do
      schema["nullable"] && is_nil(data) ->
        []

      !is_list(data) ->
        [
          %ErrorPath{
            instance_path: ip,
            schema_path: sp ++ ["elements"]
          }
        ]

      true ->
        data
        |> Enum.with_index()
        |> Enum.flat_map(fn {val, idx} ->
          do_validate(
            elem_schema,
            val,
            ip ++ [idx],
            sp ++ ["elements"],
            root
          )
        end)
    end
  end

  defp do_validate(%{"properties" => props} = schema, data, ip, sp, root) when is_map(data) do
    optional_props = Map.get(schema, "optionalProperties", %{})
    additional_allowed = Map.get(schema, "additionalProperties", false)

    req_errors = validate_properties_map(props, data, ip, sp, root, "properties")
    opt_errors = validate_properties_map(optional_props, data, ip, sp, root, "optionalProperties")

    add_errors =
      if additional_allowed do
        []
      else
        additional_schema_path =
          if map_size(optional_props) == 0 and sp == [] do
            ["properties"]
          else
            sp
          end

        data
        |> Map.keys()
        |> Enum.reject(fn k -> Map.has_key?(props, k) or Map.has_key?(optional_props, k) end)
        |> Enum.map(&%ErrorPath{instance_path: ip ++ [&1], schema_path: additional_schema_path})
      end

    req_errors ++ opt_errors ++ add_errors
  end

  defp do_validate(%{"properties" => _}, _data, ip, sp, _root) do
    [
      %ErrorPath{
        instance_path: ip,
        schema_path: sp ++ ["properties"]
      }
    ]
  end

  defp do_validate(%{"values" => val_schema}, data, ip, sp, root) when is_map(data) do
    data
    |> Enum.flat_map(fn {k, v} ->
      do_validate(
        val_schema,
        v,
        ip ++ [k],
        sp ++ ["values"],
        root
      )
    end)
  end

  defp do_validate(%{"values" => _}, _data, ip, sp, _root) do
    [
      %ErrorPath{
        instance_path: ip,
        schema_path: sp ++ ["values"]
      }
    ]
  end

  defp do_validate(
         %{"discriminator" => discr, "mapping" => mapping} = schema,
         data,
         ip,
         sp,
         root
       )
       when is_map(data) do
    cond do
      schema["nullable"] && is_nil(data) ->
        []

      !Map.has_key?(data, discr) ->
        [
          %ErrorPath{
            instance_path: ip,
            schema_path: sp ++ ["discriminator"]
          }
        ]

      !is_binary(data[discr]) ->
        [
          %ErrorPath{
            instance_path: ip ++ [discr],
            schema_path: sp ++ ["discriminator"]
          }
        ]

      !Map.has_key?(mapping, data[discr]) ->
        [
          %ErrorPath{
            instance_path: ip ++ [discr],
            schema_path: sp ++ ["mapping"]
          }
        ]

      true ->
        selected = mapping[data[discr]]

        do_validate(
          selected,
          Map.delete(data, discr),
          ip,
          sp ++ ["mapping", data[discr]],
          root
        )
    end
  end

  defp do_validate(%{"discriminator" => _}, _data, ip, sp, _root) do
    [
      %ErrorPath{
        instance_path: ip,
        schema_path: sp ++ ["discriminator"]
      }
    ]
  end

  defp do_validate(_schema, _data, _ip, _sp, _root), do: []

  defp validate_properties_map(props_map, data, ip, sp, root, base_path_key) do
    Enum.flat_map(props_map, fn {k, v} ->
      case Map.fetch(data, k) do
        {:ok, val} ->
          do_validate(v, val, ip ++ [k], sp ++ [base_path_key, k], root)

        :error ->
          if base_path_key == "properties" do
            instance_path = if "mapping" in sp, do: ip, else: ip ++ [k]
            [%ErrorPath{instance_path: instance_path, schema_path: sp ++ [base_path_key, k]}]
          else
            []
          end
      end
    end)
  end

  defp type_valid?("boolean", val), do: is_boolean(val)
  defp type_valid?("string", val), do: is_binary(val)
  defp type_valid?("float32", val), do: is_number(val)
  defp type_valid?("float64", val), do: is_number(val)

  defp type_valid?("int8", val) do
    is_integer(val) or
      (is_float(val) and val == trunc(val))
  end

  defp type_valid?("uint8", val), do: is_integer(val) and val >= 0 and val <= 255

  defp type_valid?("int16", val) do
    is_integer(val) or
      (is_float(val) and val == trunc(val))
  end

  defp type_valid?("uint16", val), do: is_integer(val) and val >= 0
  defp type_valid?("int32", val), do: is_integer(val)
  defp type_valid?("uint32", val), do: is_integer(val) and val >= 0

  defp type_valid?("timestamp", val) do
    is_binary(val) and rfc3339_valid?(val)
  end

  defp rfc3339_valid?(str) do
    regex = ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/
    String.match?(str, regex)
  end

  def valid_schema?(schema) when is_map(schema) do
    case internal_valid_schema?(schema, :root, %{}) do
      true -> {:ok, true}
      false -> {:ok, false}
    end
  end

  defp internal_valid_schema?(%{"definitions" => defs} = schema, :root, refs)
       when is_map(defs) do
    new_refs = Map.merge(refs, defs)

    Enum.all?(defs, fn {_name, def_schema} ->
      internal_valid_schema?(def_schema, :non_root, new_refs)
    end) and
      internal_valid_schema?(Map.delete(schema, "definitions"), :non_root, new_refs)
  end

  defp internal_valid_schema?(%{"properties" => props, "optionalProperties" => opt_props}, level, refs)
       when is_map(props) and is_map(opt_props) do
    no_overlap? = disjoint_keys?(props, opt_props)

    no_overlap? and
      Enum.all?(props, fn {_k, v} -> internal_valid_schema?(v, level, refs) end) and
      Enum.all?(opt_props, fn {_k, v} -> internal_valid_schema?(v, level, refs) end)
  end

  defp internal_valid_schema?(%{"definitions" => _}, :non_root, _refs), do: false

  defp internal_valid_schema?(%{"ref" => ref} = schema, :non_root, refs) do
    form_keys = Map.keys(schema) -- ["ref", "nullable", "definitions"]
    form_keys == [] and Map.has_key?(refs, ref)
  end

  defp internal_valid_schema?(%{"type" => type} = schema, _level, _refs) do
    form_keys = Map.keys(schema) -- ["type", "nullable"]
    form_keys == [] and MapSet.member?(@types, type)
  end

  defp internal_valid_schema?(%{"enum" => values} = schema, _level, _refs) when is_list(values) do
    form_keys = Map.keys(schema) -- ["enum", "nullable"]

    form_keys == [] and
      values != [] and
      Enum.all?(values, &is_binary/1) and
      MapSet.size(MapSet.new(values)) == length(values)
  end

  defp internal_valid_schema?(%{"nullable" => val}, _level, _refs) when is_boolean(val), do: true

  defp internal_valid_schema?(%{"nullable" => val}, _level, _refs) when not is_boolean(val),
    do: false

  defp internal_valid_schema?(
         %{"discriminator" => discr, "mapping" => mapping} = schema,
         level,
         refs
       )
       when is_binary(discr) and is_map(mapping) and map_size(mapping) > 0 do
    form_keys = Map.keys(schema) -- ["discriminator", "mapping", "nullable"]

    form_keys == [] and
      Enum.all?(mapping, fn {_tag, schema} ->
        no_nullable? = not Map.has_key?(schema, "nullable")

        no_discriminator_in_props? =
          case schema do
            %{"properties" => props} when is_map(props) ->
              not Map.has_key?(props, discr)

            _ ->
              true
          end

        no_discriminator_in_optional_props? =
          case schema do
            %{"optionalProperties" => opt_props} when is_map(opt_props) ->
              not Map.has_key?(opt_props, discr)

            _ ->
              true
          end

        object_schema? =
          Map.has_key?(schema, "properties") or
            Map.has_key?(schema, "optionalProperties")

        object_schema? and
          no_nullable? and
          no_discriminator_in_props? and
          no_discriminator_in_optional_props? and
          internal_valid_schema?(schema, level, refs)
      end)
  end

  defp internal_valid_schema?(%{} = schema, _level, _refs) when map_size(schema) == 0, do: true

  defp internal_valid_schema?(schema, level, refs) when is_map(schema) do
    Enum.all?(schema, fn {_k, v} ->
      internal_valid_schema?(v, level, refs)
    end)
  end

  defp internal_valid_schema?(_other, _level, _refs), do: false

  defp disjoint_keys?(a, b) do
    MapSet.disjoint?(MapSet.new(Map.keys(a)), MapSet.new(Map.keys(b)))
  end
end
