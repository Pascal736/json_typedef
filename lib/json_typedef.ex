defmodule Typedef do
  @type schema :: map()
  @type data :: term()
  @type validation_result :: {:ok, true} | {:error, [Typedef.ErrorPath.t()]}
  @type schema_validation_result :: {:ok, boolean()}

  @spec validate(schema(), data()) :: validation_result()
  defdelegate validate(schema, data), to: Typedef.Validate

  @spec valid_schema?(schema()) :: schema_validation_result()
  defdelegate valid_schema?(schema), to: Typedef.ValidSchema

  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("\n## Installation", parts: 2)
             |> then(fn [preamble, body] ->
               description =
                 preamble
                 |> String.split("\n")
                 |> Enum.reject(&(&1 =~ ~r/^#|^\s*\[/))
                 |> Enum.join("\n")
                 |> String.trim()

               description <> "\n\n## Installation" <> body
             end)
             |> String.split("\n## Documentation", parts: 2)
             |> List.first()
end
