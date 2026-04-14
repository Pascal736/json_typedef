defmodule Typedef.Schema do
  alias Typedef.Properties
  alias Typedef.Property
  alias Typedef.Empty

  defstruct [:inner]

  def new(), do: %__MODULE__{inner: %Empty{}}

  def to_map(%__MODULE__{inner: %Properties{} = props}) do
    Properties.to_map(props)
  end

  def add(%__MODULE__{inner: %Empty{}} = schema, %Property{} = prop) do
    %{schema | inner: %Properties{properties: %{prop.name => prop}}}
  end

  def add(%__MODULE__{inner: %Properties{properties: existing}} = schema, %Property{} = prop) do
    %{schema | inner: %Properties{properties: Map.put(existing, prop.name, prop)}}
  end

  def delete(%__MODULE__{inner: %Properties{} = props} = schema, name) when is_binary(name) do
    %{schema | inner: Properties.delete(props, name)}
  end

  def delete(%__MODULE__{inner: %Properties{} = props} = schema, name, path) when is_binary(name) and is_list(path) do
    %{schema | inner: Properties.delete(props, name, path)}
  end

  def update(%__MODULE__{inner: %Properties{} = props} = schema, %Property{} = prop) do
    %{schema | inner: Properties.update(props, prop)}
  end

  def update(%__MODULE__{inner: %Properties{} = props} = schema, %Property{} = prop, path) when is_list(path) do
    %{schema | inner: Properties.update(props, prop, path)}
  end
end
