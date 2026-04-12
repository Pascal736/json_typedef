defmodule TypedefTest.SchemaTest do
  use ExUnit.Case
  alias Typedef.Schema.Properties
  alias ElixirLS.LanguageServer.Plugins.Ecto.Schema
  alias Typedef.Property
  alias Typedef.Schema.Empty
  alias Typedef.Schema

  describe "new/0" do
    test "creates an empty schema" do
      assert %Schema{inner: %Empty{}} == Schema.new()
    end
  end

  describe "add_property/2" do
    test "add a new property to an empty schema" do
      schema = Schema.new()
      property = Property.simple("firstName", "string")

      schema = schema |> Schema.add(property) |> Schema.to_map()

      assert schema == %{"properties" => %{"firstName" => %{"type" => "string"}}}
    end

    test "add a new property to an non empty schema" do
      schema = Schema.new()
      property = Property.simple("firstName", "string")
      property2 = Property.simple("lastName", "string")

      schema = schema |> Schema.add(property) |> Schema.add(property2) |> Schema.to_map()

      assert schema == %{"properties" => %{"firstName" => %{"type" => "string"}, "lastName" => %{"type" => "string"}}}
    end
  end
end
