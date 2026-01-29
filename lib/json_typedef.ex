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

  def validate(_schema, _data) do
    # Add 'allow_additional_properties?' mode. Having field: 'additionalProperties': true in the schema turns this mode on.
  end

  def valid_schema?(schema) when is_map(schema) do
    case internal_valid_schema?(schema, :root, %{}) do
      true -> {:ok, true}
      false -> {:ok, false}
    end
  end

  defp internal_valid_schema?(%{"definitions" => defs} = schema, :root, refs) when is_map(defs) do
    Enum.all?(defs, fn {_name, def_schema} ->
      internal_valid_schema?(def_schema, :non_root, refs)
    end) and
      internal_valid_schema?(Map.delete(schema, "definitions"), :non_root, refs)
  end

  defp internal_valid_schema?(%{"definitions" => _}, :non_root, _refs), do: false
  defp internal_valid_schema?(%{"ref" => ref}, :non_root, refs), do: Map.has_key?(refs, ref)
  defp internal_valid_schema?(%{"type" => type}, _level, _refs), do: MapSet.member?(@types, type)

  defp internal_valid_schema?(%{"enum" => values}, _level, _refs) when is_list(values) do
    values != [] and
      Enum.all?(values, &is_binary/1) and
      MapSet.size(MapSet.new(values)) == length(values)
  end

  defp internal_valid_schema?(%{} = schema, _level, _refs) when map_size(schema) == 0, do: true
  defp internal_valid_schema?(%{"nullable" => val}, _level, _refs) when is_boolean(val), do: true

  defp internal_valid_schema?(%{"nullable" => val}, _level, _refs) when not is_boolean(val),
    do: false

  defp internal_valid_schema?(schema, level, refs) when is_map(schema) do
    Enum.all?(schema, fn {_k, v} ->
      internal_valid_schema?(v, level, refs)
    end)
  end

  defp internal_valid_schema?(_other, _level, _refs), do: false
end

# root schema -> Top level schema
# possible types: ref, type, enum, elemets, properties, values, discriminator, empty
# optional: metadata, nullable
#
