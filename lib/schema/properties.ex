defmodule Typedef.Properties do
  alias Typedef.Property

  defstruct [:properties]

  def update(%__MODULE__{properties: props}, %Property{} = prop) do
    %__MODULE__{properties: Map.put(props, prop.name, prop)}
  end

  def update(%__MODULE__{properties: props} = properties_struct, %Property{} = prop, [key]) do
    case Map.get(props, key) do
      %Property{} = existing ->
        new_value = %__MODULE__{properties: %{prop.name => prop}}
        %{properties_struct | properties: Map.put(props, key, %{existing | value: new_value})}

      _ ->
        {:error, :path_not_found}
    end
  end

  def update(%__MODULE__{properties: props} = properties_struct, %Property{} = prop, [head | tail]) do
    case Map.get(props, head) do
      %Property{value: %__MODULE__{} = nested} = parent ->
        updated = update(nested, prop, tail)
        %{properties_struct | properties: Map.put(props, head, %{parent | value: updated})}

      _ ->
        {:error, :path_not_found}
    end
  end

  def delete(%__MODULE__{properties: props}, name) when is_binary(name) do
    %__MODULE__{properties: Map.delete(props, name)}
  end

  def delete(%__MODULE__{properties: props} = properties_struct, name, [key]) when is_binary(name) do
    case Map.get(props, key) do
      %Property{value: %__MODULE__{} = nested} = parent ->
        updated = delete(nested, name)
        %{properties_struct | properties: Map.put(props, key, %{parent | value: updated})}

      _ ->
        {:error, :path_not_found}
    end
  end

  def delete(%__MODULE__{properties: props} = properties_struct, name, [head | tail]) when is_binary(name) do
    case Map.get(props, head) do
      %Property{value: %__MODULE__{} = nested} = parent ->
        updated = delete(nested, name, tail)
        %{properties_struct | properties: Map.put(props, head, %{parent | value: updated})}

      _ ->
        {:error, :path_not_found}
    end
  end

  def to_map(%__MODULE__{properties: properties}, acc \\ %{}) do
    props =
      Enum.reduce(properties, acc, fn {_key, property}, current_acc ->
        Property.to_map(property, current_acc)
      end)

    %{"properties" => props}
  end
end
