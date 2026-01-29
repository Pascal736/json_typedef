defmodule ValidatSchemaTest do
  use ExUnit.Case

  describe "valid_schema?/1" do
    test "valid root schema with definition" do
      schema = %{"definitions" => %{}}
      assert {:ok, true} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid root schema with nested definition" do
      schema = %{
        "definitions" => %{
          "foo" => %{
            "definitions" => %{}
          }
        }
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end
  end

  describe "valid_schema?/1 — empty form" do
    test "valid empty schema" do
      schema = %{}
      assert {:ok, true} == JsonTypedef.valid_schema?(schema)
    end

    test "valid empty schema with nullable true" do
      schema = %{
        "nullable" => true
      }

      assert {:ok, true} == JsonTypedef.valid_schema?(schema)
    end

    test "valid empty schema with nullable and metadata" do
      schema = %{
        "nullable" => true,
        "metadata" => %{
          "foo" => "bar"
        }
      }

      assert {:ok, true} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid empty schema with non-boolean nullable" do
      schema = %{
        "nullable" => "foo"
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end
  end

  describe "valid_schema?/1 — ref form" do
    test "valid ref schema with matching top-level definition" do
      schema = %{
        "definitions" => %{
          "coordinates" => %{
            "properties" => %{
              "lat" => %{"type" => "float32"},
              "lng" => %{"type" => "float32"}
            }
          }
        },
        "properties" => %{
          "user_location" => %{"ref" => "coordinates"},
          "server_location" => %{"ref" => "coordinates"}
        }
      }

      assert {:ok, true} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid ref schema without top-level definitions" do
      schema = %{
        "ref" => "foo"
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid ref schema with missing referenced definition" do
      schema = %{
        "definitions" => %{
          "foo" => %{}
        },
        "ref" => "bar"
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end
  end

  describe "valid_schema?/1 — type form" do
    test "valid type schema with uint8" do
      schema = %{
        "type" => "uint8"
      }

      assert {:ok, true} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid type schema with non-string type" do
      schema = %{
        "type" => true
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid type schema with unknown type" do
      schema = %{
        "type" => "foo"
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end
  end

  describe "valid_schema?/1 — enum form" do
    test "valid enum schema with distinct string values" do
      schema = %{
        "enum" => ["PENDING", "IN_PROGRESS", "DONE"]
      }

      assert {:ok, true} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid enum schema with empty array" do
      schema = %{
        "enum" => []
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid enum schema with duplicate values by RFC8259 string equality" do
      schema = %{
        "enum" => ["a\\b", "a\u005Cb"]
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid enum schema with non-string value" do
      schema = %{
        "enum" => ["OK", 1]
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end
  end

  describe "valid_schema?/1 — elements form" do
    test "valid elements schema with valid subschema" do
      schema = %{
        "elements" => %{
          "type" => "uint8"
        }
      }

      assert {:ok, true} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid elements schema with non-schema value" do
      schema = %{
        "elements" => true
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid elements schema with invalid subschema" do
      schema = %{
        "elements" => %{
          "type" => "foo"
        }
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end
  end

  describe "valid_schema?/1 — properties form" do
    test "invalid properties schema with overlapping required and optional property names" do
      schema = %{
        "properties" => %{
          "confusing" => %{}
        },
        "optionalProperties" => %{
          "confusing" => %{}
        }
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end

    test "valid properties schema with disjoint required and optional properties" do
      schema = %{
        "properties" => %{
          "users" => %{
            "elements" => %{
              "properties" => %{
                "id" => %{"type" => "string"},
                "name" => %{"type" => "string"},
                "create_time" => %{"type" => "timestamp"}
              },
              "optionalProperties" => %{
                "delete_time" => %{"type" => "timestamp"}
              }
            }
          },
          "next_page_token" => %{"type" => "string"}
        }
      }

      assert {:ok, true} == JsonTypedef.valid_schema?(schema)
    end
  end

  describe "valid_schema?/1 — values form" do
    test "valid values schema with valid subschema" do
      schema = %{
        "values" => %{
          "type" => "uint8"
        }
      }

      assert {:ok, true} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid values schema with non-schema value" do
      schema = %{
        "values" => true
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid values schema with invalid subschema" do
      schema = %{
        "values" => %{
          "type" => "foo"
        }
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end
  end

  describe "valid_schema?/1 — discriminator form" do
    test "invalid discriminator schema with nullable true in mapping schema" do
      schema = %{
        "discriminator" => "event_type",
        "mapping" => %{
          "can_the_object_be_null_or_not?" => %{
            "nullable" => true,
            "properties" => %{
              "foo" => %{"type" => "string"}
            }
          }
        }
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid discriminator schema redefining discriminator in properties" do
      schema = %{
        "discriminator" => "event_type",
        "mapping" => %{
          "is_event_type_a_string_or_a_float32?" => %{
            "properties" => %{
              "event_type" => %{"type" => "float32"}
            }
          }
        }
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end

    test "invalid discriminator schema redefining discriminator in optionalProperties" do
      schema = %{
        "discriminator" => "event_type",
        "mapping" => %{
          "is_event_type_a_string_or_an_optional_float32?" => %{
            "optionalProperties" => %{
              "event_type" => %{"type" => "float32"}
            }
          }
        }
      }

      assert {:ok, false} == JsonTypedef.valid_schema?(schema)
    end

    test "valid discriminator schema with disjoint properties and no nullable in mapping" do
      schema = %{
        "discriminator" => "event_type",
        "mapping" => %{
          "account_deleted" => %{
            "properties" => %{
              "account_id" => %{"type" => "string"}
            }
          },
          "account_payment_plan_changed" => %{
            "properties" => %{
              "account_id" => %{"type" => "string"},
              "payment_plan" => %{"enum" => ["FREE", "PAID"]}
            },
            "optionalProperties" => %{
              "upgraded_by" => %{"type" => "string"}
            }
          }
        }
      }

      assert {:ok, true} == JsonTypedef.valid_schema?(schema)
    end
  end
end
