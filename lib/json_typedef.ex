defmodule Typedef do
  @type schema :: map()
  @type data :: term()
  @type validation_result :: {:ok, true} | {:error, [Typedef.ErrorPath.t()]}
  @type schema_validation_result :: {:ok, boolean()}

  @spec validate(schema(), data()) :: validation_result()
  defdelegate validate(schema, data), to: Typedef.Validate

  @spec valid_schema?(schema()) :: schema_validation_result()
  defdelegate valid_schema?(schema), to: Typedef.ValidSchema
end
