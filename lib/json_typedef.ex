defmodule JsonTypedef do
  @moduledoc """
  Documentation for `JsonTypedef`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> JsonTypedef.hello()
      :world

  """
  def hello do
    :world
  end

  def validate(schema, data) do
    # Add 'allow_additional_properties?' mode. Having field: 'additionalProperties': true in the schema turns this mode on.
  end

  def valid_schema?(schema) do
  end
end

# root schema -> Top level schema
# possible types: ref, type, enum, elemets, properties, values, discriminator, empty
# optional: metadata, nullable
#
# Types: boolean, float32, float64, int8, uint8, int16, uint16, int32, uint32, string, timestamp
# Only root schemas can have a definitions object
