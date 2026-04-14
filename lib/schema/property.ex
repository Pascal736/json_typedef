defmodule Typedef.Property do
  alias Typedef.Properties
  alias Typedef.Type
  alias Typedef.Values
  alias Typedef.Elements

  defstruct [:name, :value]

  def simple(name, type) when is_binary(name) and is_binary(type) do
    %__MODULE__{name: name, value: %Type{type: type}}
  end

  def elements(name, type) when is_binary(name) and is_binary(type) do
    %__MODULE__{name: name, value: %Elements{type: type}}
  end

  def values(name, type) when is_binary(name) and is_binary(type) do
    %__MODULE__{name: name, value: %Values{value_schema: %Type{type: type}}}
  end

  def property(name, %__MODULE__{} = child) when is_binary(name) do
    %__MODULE__{name: name, value: %Properties{properties: %{child.name => child}}}
  end

  def to_map(%__MODULE__{} = property, acc \\ %{}) do
    parse_property(property, acc)
  end

  defp parse_property(%__MODULE__{name: name, value: %Type{type: type}}, acc) do
    Map.put(acc, name, %{"type" => type})
  end

  defp parse_property(%__MODULE__{name: name, value: %Elements{type: type}}, acc) do
    Map.put(acc, name, %{"elements" => %{"type" => type}})
  end

  defp parse_property(%__MODULE__{name: name, value: %Values{value_schema: %Type{type: type}}}, acc) do
    Map.put(acc, name, %{"values" => %{"type" => type}})
  end

  defp parse_property(%__MODULE__{name: name, value: %Properties{} = props}, acc) do
    Map.put(acc, name, Properties.to_map(props))
  end
end
