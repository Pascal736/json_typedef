defmodule Typedef.Schema do
  alias Typedef.Properties
  alias Typedef.Property
  alias Typedef.Empty
  alias Typedef.Simple
  alias Typedef.Elements

  defstruct [:inner]

  def new(), do: %__MODULE__{inner: %Empty{}}

  def to_map(%__MODULE__{inner: %Properties{} = props}) do
    Properties.to_map(props)
  end

  def add(%__MODULE__{inner: %Empty{}} = schema, %Property{} = prop) do
    %{schema | inner: %Properties{properties: [prop]}}
  end

  def add(%__MODULE__{inner: %Properties{properties: existing}} = schema, %Property{} = prop) do
    %{schema | inner: %Properties{properties: [prop | existing]}}
  end

  def add(%__MODULE__{inner: %Simple{}}, %Property{}) do
    {:error, :cannot_add_property_to_simple_schema}
  end
end
