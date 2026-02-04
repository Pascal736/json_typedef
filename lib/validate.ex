defmodule Typedef.Validate do
  alias Typedef.ErrorPath

  @spec validate(map(), term()) :: {:ok, true} | {:error, [ErrorPath.t()]}
  def validate(schema, data) do
    errors = do_validate(schema, data, [], [], schema)
    if errors == [], do: {:ok, true}, else: {:error, errors}
  end

  defp do_validate(%{"nullable" => true}, nil, _ip, _sp, _root), do: []

  defp do_validate(%{"ref" => ref, "definitions" => defs} = schema, data, ip, sp, root) do
    case Map.fetch(defs, ref) do
      {:ok, ref_schema} ->
        merged_schema = Map.merge(ref_schema, Map.drop(schema, ["ref", "definitions"]))

        do_validate(
          merged_schema,
          data,
          ip,
          sp ++ ["definitions", ref],
          root
        )

      :error ->
        [
          %ErrorPath{
            instance_path: ip,
            schema_path: sp ++ ["definitions", ref]
          }
        ]
    end
  end

  defp do_validate(%{"type" => type} = schema, data, ip, sp, _root) do
    cond do
      schema["nullable"] && is_nil(data) ->
        []

      type_valid?(type, data) ->
        []

      true ->
        [
          %ErrorPath{
            instance_path: ip,
            schema_path: sp ++ ["type"]
          }
        ]
    end
  end

  defp do_validate(%{"enum" => values} = schema, data, ip, sp, _root) do
    cond do
      schema["nullable"] && is_nil(data) ->
        []

      data in values ->
        []

      true ->
        [
          %ErrorPath{
            instance_path: ip,
            schema_path: sp ++ ["enum"]
          }
        ]
    end
  end

  defp do_validate(%{"elements" => elem_schema} = schema, data, ip, sp, root) do
    cond do
      schema["nullable"] && is_nil(data) ->
        []

      !is_list(data) ->
        [
          %ErrorPath{
            instance_path: ip,
            schema_path: sp ++ ["elements"]
          }
        ]

      true ->
        data
        |> Enum.with_index()
        |> Enum.flat_map(fn {val, idx} ->
          do_validate(
            elem_schema,
            val,
            ip ++ [idx],
            sp ++ ["elements"],
            root
          )
        end)
    end
  end

  defp do_validate(%{"properties" => props} = schema, data, ip, sp, root) when is_map(data) do
    optional_props = Map.get(schema, "optionalProperties", %{})
    additional_allowed = Map.get(schema, "additionalProperties", false)

    req_errors = validate_properties_map(props, data, ip, sp, root, "properties")
    opt_errors = validate_properties_map(optional_props, data, ip, sp, root, "optionalProperties")

    add_errors =
      if additional_allowed do
        []
      else
        additional_schema_path =
          if map_size(optional_props) == 0 and sp == [] do
            ["properties"]
          else
            sp
          end

        data
        |> Map.keys()
        |> Enum.reject(fn k -> Map.has_key?(props, k) or Map.has_key?(optional_props, k) end)
        |> Enum.map(&%ErrorPath{instance_path: ip ++ [&1], schema_path: additional_schema_path})
      end

    req_errors ++ opt_errors ++ add_errors
  end

  defp do_validate(%{"properties" => _}, _data, ip, sp, _root) do
    [
      %ErrorPath{
        instance_path: ip,
        schema_path: sp ++ ["properties"]
      }
    ]
  end

  defp do_validate(%{"values" => val_schema}, data, ip, sp, root) when is_map(data) do
    data
    |> Enum.flat_map(fn {k, v} ->
      do_validate(
        val_schema,
        v,
        ip ++ [k],
        sp ++ ["values"],
        root
      )
    end)
  end

  defp do_validate(%{"values" => _}, _data, ip, sp, _root) do
    [
      %ErrorPath{
        instance_path: ip,
        schema_path: sp ++ ["values"]
      }
    ]
  end

  defp do_validate(
         %{"discriminator" => discr, "mapping" => mapping} = schema,
         data,
         ip,
         sp,
         root
       )
       when is_map(data) do
    cond do
      schema["nullable"] && is_nil(data) ->
        []

      !Map.has_key?(data, discr) ->
        [
          %ErrorPath{
            instance_path: ip,
            schema_path: sp ++ ["discriminator"]
          }
        ]

      !is_binary(data[discr]) ->
        [
          %ErrorPath{
            instance_path: ip ++ [discr],
            schema_path: sp ++ ["discriminator"]
          }
        ]

      !Map.has_key?(mapping, data[discr]) ->
        [
          %ErrorPath{
            instance_path: ip ++ [discr],
            schema_path: sp ++ ["mapping"]
          }
        ]

      true ->
        selected = mapping[data[discr]]

        do_validate(
          selected,
          Map.delete(data, discr),
          ip,
          sp ++ ["mapping", data[discr]],
          root
        )
    end
  end

  defp do_validate(%{"discriminator" => _}, _data, ip, sp, _root) do
    [
      %ErrorPath{
        instance_path: ip,
        schema_path: sp ++ ["discriminator"]
      }
    ]
  end

  defp do_validate(_schema, _data, _ip, _sp, _root), do: []

  defp validate_properties_map(props_map, data, ip, sp, root, base_path_key) do
    Enum.flat_map(props_map, fn {k, v} ->
      case Map.fetch(data, k) do
        {:ok, val} ->
          do_validate(v, val, ip ++ [k], sp ++ [base_path_key, k], root)

        :error ->
          if base_path_key == "properties" do
            instance_path = if "mapping" in sp, do: ip, else: ip ++ [k]
            [%ErrorPath{instance_path: instance_path, schema_path: sp ++ [base_path_key, k]}]
          else
            []
          end
      end
    end)
  end

  defp type_valid?("boolean", val), do: is_boolean(val)
  defp type_valid?("string", val), do: is_binary(val)
  defp type_valid?("float32", val), do: is_number(val)
  defp type_valid?("float64", val), do: is_number(val)

  defp type_valid?("int8", val) do
    is_integer(val) or
      (is_float(val) and val == trunc(val))
  end

  defp type_valid?("uint8", val), do: is_integer(val) and val >= 0 and val <= 255

  defp type_valid?("int16", val) do
    is_integer(val) or
      (is_float(val) and val == trunc(val))
  end

  defp type_valid?("uint16", val), do: is_integer(val) and val >= 0
  defp type_valid?("int32", val), do: is_integer(val)
  defp type_valid?("uint32", val), do: is_integer(val) and val >= 0

  defp type_valid?("timestamp", val) do
    is_binary(val) and rfc3339_valid?(val)
  end

  defp rfc3339_valid?(str) do
    regex = ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/
    String.match?(str, regex)
  end
end
