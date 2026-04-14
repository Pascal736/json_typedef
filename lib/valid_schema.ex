defmodule Typedef.ValidSchema do
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

  @spec valid_schema?(map()) :: {:ok, boolean()}
  def valid_schema?(schema) when is_map(schema) do
    case internal_valid_schema?(schema, :root, %{}) do
      true -> {:ok, true}
      false -> {:ok, false}
    end
  end

  @spec valid_schema?(map()) :: :ok
  def valid_schema!(schema) when is_map(schema) do
    case internal_valid_schema?(schema, :root, %{}) do
      true -> :ok
      false -> raise "Invalid schema"
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
