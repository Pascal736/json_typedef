defmodule JsonTypedef do
  @type schema :: map()
  @type data :: term()
  @type validation_result :: {:ok, true} | {:error, [JsonTypedef.ErrorPath.t()]}
  @type schema_validation_result :: {:ok, boolean()}

  @spec validate(schema(), data()) :: validation_result()
  defdelegate validate(schema, data), to: JsonTypedef.Validate

  @spec valid_schema?(schema()) :: schema_validation_result()
  defdelegate valid_schema?(schema), to: JsonTypedef.ValidSchema
end
