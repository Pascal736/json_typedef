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
  @forms ["type", "enum", "ref", "properties", "values", "elements", "discriminator"]

  alias JsonTypedef.ErrorPath

  def validate(schema, data) do
    errors = do_validate(schema, data, "", schema)
    if errors == [], do: {:ok, true}, else: {:error, errors}
  end

  defp do_validate(%{"nullable" => true}, nil, _path, _root_schema), do: []

  defp do_validate(%{"ref" => ref, "definitions" => defs} = schema, data, path, root_schema) do
    case Map.fetch(defs, ref) do
      {:ok, ref_schema} ->
        merged_schema = Map.merge(ref_schema, Map.drop(schema, ["ref", "definitions"]))
        do_validate(merged_schema, data, path, root_schema)

      :error ->
        [%ErrorPath{instance_path: path, schema_path: "/definitions/#{ref}"}]
    end
  end

  defp do_validate(%{"type" => type} = schema, data, path, _root) do
    cond do
      schema["nullable"] && is_nil(data) -> []
      type_valid?(type, data) -> []
      true -> [%ErrorPath{instance_path: path, schema_path: "/type"}]
    end
  end

  defp do_validate(%{"enum" => values} = schema, data, path, _root) do
    cond do
      schema["nullable"] && is_nil(data) -> []
      data in values -> []
      true -> [%ErrorPath{instance_path: path, schema_path: "/enum"}]
    end
  end

  defp do_validate(%{"elements" => elem_schema} = schema, data, path, root) do
    cond do
      schema["nullable"] && is_nil(data) ->
        []

      !is_list(data) ->
        [%ErrorPath{instance_path: path, schema_path: "/elements"}]

      true ->
        data
        |> Enum.with_index()
        |> Enum.flat_map(fn {val, idx} ->
          do_validate(elem_schema, val, "#{path}/#{idx}", root)
        end)
    end
  end

  defp do_validate(%{"properties" => props} = schema, data, path, root) when is_map(data) do
    optional_props = Map.get(schema, "optionalProperties", %{})
    additional_allowed = Map.get(schema, "additionalProperties", false)

    req_errors =
      props
      |> Enum.flat_map(fn {k, v} ->
        case Map.fetch(data, k) do
          {:ok, val} -> do_validate(v, val, "#{path}/#{k}", root)
          :error -> [%ErrorPath{instance_path: path <> "/" <> k, schema_path: "/properties/#{k}"}]
        end
      end)

    opt_errors =
      optional_props
      |> Enum.flat_map(fn {k, v} ->
        case Map.fetch(data, k) do
          {:ok, val} -> do_validate(v, val, "#{path}/#{k}", root)
          :error -> []
        end
      end)

    add_errors =
      if additional_allowed do
        []
      else
        data
        |> Map.keys()
        |> Enum.filter(fn k -> not Map.has_key?(props, k) and not Map.has_key?(optional_props, k) end)
        |> Enum.map(fn k ->
          %ErrorPath{instance_path: "#{path}/#{k}", schema_path: path || "/properties"}
        end)
      end

    req_errors ++ opt_errors ++ add_errors
  end

  defp do_validate(%{"properties" => _}, data, path, _root), do: [%ErrorPath{instance_path: path, schema_path: "/properties"}]

  defp do_validate(%{"values" => val_schema}, data, path, root) when is_map(data) do
    data
    |> Enum.flat_map(fn {k, v} ->
      do_validate(val_schema, v, "#{path}/#{k}", root)
    end)
  end

  defp do_validate(%{"values" => _}, _data, path, _root), do: [%ErrorPath{instance_path: path, schema_path: "/values"}]

  defp do_validate(%{"discriminator" => discr, "mapping" => mapping} = schema, data, path, root) when is_map(data) do
    cond do
      schema["nullable"] && is_nil(data) ->
        []

      !Map.has_key?(data, discr) ->
        [%ErrorPath{instance_path: path, schema_path: "/discriminator"}]

      !is_binary(data[discr]) ->
        [%ErrorPath{instance_path: "#{path}/#{discr}", schema_path: "/discriminator"}]

      !Map.has_key?(mapping, data[discr]) ->
        [%ErrorPath{instance_path: "#{path}/#{discr}", schema_path: "/mapping"}]

      true ->
        selected = mapping[data[discr]]
        do_validate(selected, Map.delete(data, discr), path, root)
    end
  end

  defp do_validate(%{"discriminator" => _}, _data, path, _root),
    do: [%ErrorPath{instance_path: path, schema_path: "/discriminator"}]

  defp do_validate(_schema, _data, _path, _root), do: []

  defp type_valid?("boolean", val), do: is_boolean(val)
  defp type_valid?("string", val), do: is_binary(val)
  defp type_valid?("float32", val), do: is_number(val)
  defp type_valid?("float64", val), do: is_number(val)
  defp type_valid?("int8", val), do: is_integer(val) or (is_float(val) and rem(val, 1) == 0)
  defp type_valid?("uint8", val), do: is_integer(val) and val >= 0 and val <= 255
  defp type_valid?("int16", val), do: is_integer(val)
  defp type_valid?("uint16", val), do: is_integer(val) and val >= 0
  defp type_valid?("int32", val), do: is_integer(val)
  defp type_valid?("uint32", val), do: is_integer(val) and val >= 0
  # TODO: add RFC3339 validation
  defp type_valid?("timestamp", val), do: is_binary(val)

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
  defp internal_valid_schema?(%{"ref" => ref}, :non_root, refs), do: Map.has_key?(refs, ref)
  defp internal_valid_schema?(%{"type" => type}, _level, _refs), do: MapSet.member?(@types, type)

  defp internal_valid_schema?(%{"enum" => values}, _level, _refs) when is_list(values) do
    values != [] and
      Enum.all?(values, &is_binary/1) and
      MapSet.size(MapSet.new(values)) == length(values)
  end

  defp internal_valid_schema?(%{"nullable" => val}, _level, _refs) when is_boolean(val), do: true

  defp internal_valid_schema?(%{"nullable" => val}, _level, _refs) when not is_boolean(val),
    do: false

  # defp internal_valid_schema?(%{"discriminator" => _, "mapping" => _} = schema, _level, _refs) when map_size(schema) > 2,
  #   do: false

  defp internal_valid_schema?(
         %{"discriminator" => discr, "mapping" => mapping},
         level,
         refs
       )
       when is_binary(discr) and is_map(mapping) and map_size(mapping) > 0 do
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
