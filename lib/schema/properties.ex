defmodule Typedef.Properties do
  alias Typedef.Property

  defstruct [:properties]

  def update(%__MODULE__{properties: props}, %Property{} = prop) do
    %__MODULE__{properties: Map.put(props, prop.name, prop)}
  end

  def update(%__MODULE__{properties: props}, %Property{} = prop, path) when is_list(path) do
    %__MODULE__{properties: update_nested(props, path, prop)}
  end

  def to_map(%__MODULE__{properties: properties}, acc \\ %{}) do
    props =
      Enum.reduce(properties, acc, fn {_key, property}, current_acc ->
        Property.to_map(property, current_acc)
      end)

    %{"properties" => props}
  end

  defp update_nested(properties, [key], value) do
    Map.put(properties, key, value)
  end

  defp update_nested(properties, [head | tail], value) do
    case Map.get(properties, head) do
      %Property{value: %__MODULE__{properties: nested}} = prop ->
        updated_nested = update_nested(nested, tail, value)

        Map.put(properties, head, %{prop | value: %__MODULE__{properties: updated_nested}})

      _ ->
        {:error, :path_not_found}
    end
  end
end
