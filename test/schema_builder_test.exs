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

  describe "add/2" do
    test "adds a new property to an empty schema" do
      schema = Schema.new()
      property = Property.simple("firstName", "string")

      schema = schema |> Schema.add(property) |> Schema.to_map()

      assert schema == %{"properties" => %{"firstName" => %{"type" => "string"}}}
      assert :ok = Typedef.valid_schema!(schema)
    end

    test "adds a new property to an non empty schema" do
      schema = Schema.new()
      property = Property.simple("firstName", "string")
      property2 = Property.simple("lastName", "string")

      schema = schema |> Schema.add(property) |> Schema.add(property2) |> Schema.to_map()

      assert schema == %{"properties" => %{"firstName" => %{"type" => "string"}, "lastName" => %{"type" => "string"}}}
      assert :ok = Typedef.valid_schema!(schema)
    end

    test "adds elements property" do
      schema = Schema.new()
      property = Property.elements("items", "string")

      schema = schema |> Schema.add(property) |> Schema.to_map()

      assert schema == %{"properties" => %{"items" => %{"elements" => %{"type" => "string"}}}}
    end

    test "adds elements property to an non empty schema" do
      schema = Schema.new()
      property = Property.simple("firstName", "string")
      property2 = Property.elements("items", "string")

      schema = schema |> Schema.add(property) |> Schema.add(property2) |> Schema.to_map()

      assert schema == %{
               "properties" => %{"firstName" => %{"type" => "string"}, "items" => %{"elements" => %{"type" => "string"}}}
             }

      assert :ok = Typedef.valid_schema!(schema)
    end

    test "adds a nested property to property" do
      schema = Schema.new()
      node_property = Property.simple("firstName", "string")
      property = Property.property("nestedNode", node_property)

      schema = schema |> Schema.add(property) |> Schema.to_map()

      assert schema == %{"properties" => %{"nestedNode" => %{"properties" => %{"firstName" => %{"type" => "string"}}}}}
      assert :ok = Typedef.valid_schema!(schema)
    end
  end

  describe "update/3" do
    test "updates property field on root node" do
      schema = Schema.new()
      property = Property.simple("firstName", "string")
      property2 = Property.elements("items", "string")

      schema = schema |> Schema.add(property) |> Schema.add(property2)

      updated_property = Property.simple("firstName", "boolean")
      schema = schema |> Schema.update(updated_property) |> Schema.to_map()

      assert schema == %{
               "properties" => %{"firstName" => %{"type" => "boolean"}, "items" => %{"elements" => %{"type" => "string"}}}
             }

      assert :ok = Typedef.valid_schema!(schema)
    end

    test "updates nested property field" do
      schema = Schema.new()
      node_property = Property.simple("firstName", "string")
      property = Property.property("nestedNode", node_property)

      schema = schema |> Schema.add(property)

      updated_property = Property.simple("firstName", "boolean")
      schema = schema |> Schema.update(updated_property, ["nestedNode"]) |> Schema.to_map()

      assert schema == %{"properties" => %{"nestedNode" => %{"properties" => %{"firstName" => %{"type" => "boolean"}}}}}
      assert :ok = Typedef.valid_schema!(schema)
    end

    test "updates deeply nested property" do
      schema = Schema.new()
      property1 = Property.simple("level1", "string")
      property2 = Property.property("level2", property1)
      property2 = Property.property("level3", property2)

      schema = schema |> Schema.add(property2)

      updated_property = Property.simple("newLevel1", "boolean")
      schema = schema |> Schema.update(updated_property, ["level3", "level2"]) |> Schema.to_map()

      assert schema == %{
               "properties" => %{
                 "level3" => %{"properties" => %{"level2" => %{"properties" => %{"newLevel1" => %{"type" => "boolean"}}}}}
               }
             }

      assert :ok = Typedef.valid_schema!(schema)
    end

    test "updates element property" do
      schema = Schema.new()
      property = Property.elements("items", "string")
      schema = Schema.add(schema, property)

      updated_property = Property.elements("items", "boolean")
      schema = schema |> Schema.update(updated_property) |> Schema.to_map()

      assert schema == %{"properties" => %{"items" => %{"elements" => %{"type" => "boolean"}}}}
      assert :ok = Typedef.valid_schema!(schema)
    end
  end
end
