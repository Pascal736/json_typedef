defmodule Typedef.Schema do
  alias Typedef.Properties
  alias Typedef.Property
  alias Typedef.Empty
  alias Typedef.Values
  alias Typedef.Type

  defstruct [:inner]

  def new(), do: %__MODULE__{inner: %Empty{}}

  def values(type) when is_binary(type) do
    %__MODULE__{inner: %Values{value_schema: %Type{type: type}}}
  end

  def to_map(%__MODULE__{inner: %Properties{} = props}) do
    Properties.to_map(props)
  end

  def to_map(%__MODULE__{inner: %Values{value_schema: %Type{type: type}}}) do
    %{"values" => %{"type" => type}}
  end

  def add(%__MODULE__{inner: %Empty{}} = schema, %Property{} = prop) do
    %{schema | inner: %Properties{properties: %{prop.name => prop}}}
  end

  def add(%__MODULE__{inner: %Properties{properties: existing}} = schema, %Property{} = prop) do
    %{schema | inner: %Properties{properties: Map.put(existing, prop.name, prop)}}
  end

  def add(%__MODULE__{inner: %Properties{} = props} = schema, %Property{} = prop, path) when is_list(path) do
    %{schema | inner: Properties.add(props, prop, path)}
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
