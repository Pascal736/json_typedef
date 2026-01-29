defmodule JsonTypedef do
  def validate(_schema, _data) do
    # Add 'allow_additional_properties?' mode. Having field: 'additionalProperties': true in the schema turns this mode on.
  end

  def valid_schema?(schema) when is_map(schema) do
    case internal_valid_schema?(schema, :root) do
      true -> {:ok, true}
      false -> {:ok, false}
    end
  end

  defp internal_valid_schema?(%{"definitions" => defs} = schema, :root)
       when is_map(defs) do
    Enum.all?(defs, fn {_name, def_schema} ->
      internal_valid_schema?(def_schema, :non_root)
    end) and
      internal_valid_schema?(Map.delete(schema, "definitions"), :non_root)
  end

  defp internal_valid_schema?(%{"definitions" => _}, :non_root), do: false

  defp internal_valid_schema?(schema, level) when is_map(schema) do
    Enum.all?(schema, fn {_k, v} ->
      internal_valid_schema?(v, level)
    end)
  end

  defp internal_valid_schema?(_other, _level), do: true
end

# root schema -> Top level schema
# possible types: ref, type, enum, elemets, properties, values, discriminator, empty
# optional: metadata, nullable
#
# Types: boolean, float32, float64, int8, uint8, int16, uint16, int32, uint32, string, timestamp
# Only root schemas can have a definitions object
