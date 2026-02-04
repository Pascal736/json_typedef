# Typedef

[![Hex.pm](https://img.shields.io/hexpm/v/typedef.svg)](https://hex.pm/packages/typedef)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/typedef)

A pure Elixir implementation of [RFC8927](https://datatracker.ietf.org/doc/html/rfc8927).
Validates data against [JSON Typedef](https://jsontypedef.com/) schemas.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `typedef` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:typedef, "~> 0.0.1"}
  ]
end
```

## Quick Start

```elixir
iex> schema = %{
...>   "properties" => %{
...>     "name" => %{"type" => "string"},
...>     "age" => %{"type" => "uint32"},
...>     "phones" => %{
...>       "elements" => %{
...>         "type" => "string"
...>       }
...>     }
...>   }
...> }
iex>
iex> {:ok, true} = Typedef.valid_schema?(schema)
iex>
iex> Typedef.validate(schema, %{
...>   "name" => "John Doe",
...>   "age" => 43,
...>   "phones" => ["+44 1234567", "+44 2345678"]
...> })
{:ok, true}
iex>
iex> # Invalid data returns error paths showing what failed
iex> {:error, errors} = Typedef.validate(schema, %{
...>   "age" => "43",
...>   "phones" => ["+44 1234567", 999]
...> })
iex> errors
[%Typedef.ErrorPath{instance_path: ["age"], schema_path: ["properties", "age", "type"]}, %Typedef.ErrorPath{instance_path: ["name"], schema_path: ["properties", "name"]}, %Typedef.ErrorPath{instance_path: ["phones", 1], schema_path: ["properties", "phones", "elements", "type"]}]
```


