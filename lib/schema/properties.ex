defmodule Typedef.Properties do
  alias Typedef.Simple
  alias Typedef.Elements
  alias Typedef.Property

  defstruct [:properties]

  def to_map(%__MODULE__{properties: properties}, acc \\ %{}) do
    props =
      Enum.reduce(properties, acc, fn property, current_acc ->
        Property.to_map(property, current_acc)
      end)

    %{"properties" => props}
  end
end
