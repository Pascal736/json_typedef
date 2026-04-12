defmodule Typedef.Property do
  alias Typedef.Simple
  alias Typedef.Elements

  defstruct [:name, :value]

  def simple(name, type) when is_binary(name) and is_binary(type) do
    # TODO: Type check
    %__MODULE__{name: name, value: %Simple{type: type}}
  end

  def elements(name, type) when is_binary(name) and is_binary(type) do
    %__MODULE__{name: name, value: %Elements{type: type}}
  end

  def property(name, %__MODULE__{} = property) when is_binary(name) do
    %__MODULE__{name: name, value: property}
  end

  def to_map(%__MODULE__{} = property, acc \\ %{}) do
    parse_property(property, acc)
  end

  defp parse_property(%__MODULE__{name: name, value: %Simple{type: type}}, acc) do
    Map.put(acc, name, %{"type" => type})
  end

  defp parse_property(%__MODULE__{name: name, value: %Elements{type: type}}, acc) do
    Map.put(acc, name, %{"elements" => %{"type" => type}})
  end

  defp parse_property(%__MODULE__{name: name, value: %__MODULE__{} = prop}, acc) do
    Map.put(acc, name, parse_property(prop, acc))
  end
end
