defmodule Typedef.Property do
  @types MapSet.new([
           "boolean",
           "float32",
           "float64",
           "int8",
           "uint8",
           "int16",
           "uint16",
           "int32",
           "uint32",
           "string",
           "timestamp"
         ])
  defmodule Simple do
    defstruct [:type]
  end

  defstruct [:name, :value]

  def simple(name, type) when is_binary(name) and is_binary(type) do
    # TODO: Type check
    %__MODULE__{name: name, value: %Simple{type: type}}
  end
end

defmodule Typedef.Schema do
  alias Typedef.Property
  alias Typedef.Property.Simple, as: PSimple

  defmodule Empty do
    defstruct []
  end

  defmodule Simple do
    defstruct [:type]
  end

  defmodule Properties do
    defstruct properties: []
  end

  defstruct [:inner]

  def new(), do: %__MODULE__{inner: %Empty{}}

  def to_map(%__MODULE__{inner: %Properties{} = props}) do
    props = Enum.reduce(props.properties, %{}, &parse_property/2)
    %{"properties" => props}
  end

  def add(%__MODULE__{inner: %Properties{properties: existing}} = schema, %Property{} = prop) do
    %{schema | inner: %Properties{properties: [prop | existing]}}
  end

  def add(%__MODULE__{inner: %Empty{}} = schema, %Property{} = prop) do
    %{schema | inner: %Properties{properties: [prop]}}
  end

  def add(%__MODULE__{inner: %Simple{}}, %Property{}) do
    {:error, :cannot_add_property_to_simple_schema}
  end

  defp parse_property(%Property{name: name, value: %PSimple{type: type}}, acc) do
    Map.put(acc, name, %{"type" => type})
  end
end
