defmodule TypedefTest.SchemaTest do
  use ExUnit.Case
  alias Typedef.Properties
  alias Typedef.Property
  alias Typedef.Schema
  alias Typedef.Empty
  alias Typedef.Elements

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

    test "add elements property" do
      schema = Schema.new()
      property = Property.elements("items", "string")

      schema = schema |> Schema.add(property) |> Schema.to_map()

      assert schema == %{"properties" => %{"items" => %{"elements" => %{"type" => "string"}}}}
    end

    test "add elements property to an non empty schema" do
      schema = Schema.new()
      property = Property.simple("firstName", "string")
      property2 = Property.elements("items", "string")

      schema = schema |> Schema.add(property) |> Schema.add(property2) |> Schema.to_map()

      assert schema == %{
               "properties" => %{"firstName" => %{"type" => "string"}, "items" => %{"elements" => %{"type" => "string"}}}
             }
    end
  end

  describe "nested properties" do
    test "add property to property" do
      schema = Schema.new()
      node_property = Property.simple("firstName", "string")
      property = Property.property("nestedNode", node_property)

      schema = schema |> Schema.add(property) |> Schema.to_map()

      assert schema == %{"properties" => %{"nestedNode" => %{"firstName" => %{"type" => "string"}}}}
    end
  end
end
