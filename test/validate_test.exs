defmodule TypedefTest.ValidateTest do
  use ExUnit.Case
  alias Typedef.ErrorPath

  describe("validate/2 — additionalProperties") do
    test "rejects additional properties by default" do
      schema = %{
        "properties" => %{
          "a" => %{"type" => "string"}
        }
      }

      data = %{
        "a" => "foo",
        "b" => "bar"
      }

      {:error, errors} = Typedef.validate(schema, data)

      assert errors == [
               %ErrorPath{
                 instance_path: ["b"],
                 schema_path: ["properties"]
               }
             ]
    end

    test "accepts additional properties when additionalProperties is true" do
      schema = %{
        "additionalProperties" => true,
        "properties" => %{
          "a" => %{"type" => "string"}
        }
      }

      data = %{
        "a" => "foo",
        "b" => "bar"
      }

      assert {:ok, true} == Typedef.validate(schema, data)
    end

    test "additionalProperties is not inherited by subschemas" do
      schema = %{
        "additionalProperties" => true,
        "properties" => %{
          "a" => %{
            "properties" => %{
              "b" => %{"type" => "string"}
            }
          }
        }
      }

      valid_data = %{
        "a" => %{"b" => "c"},
        "foo" => "bar"
      }

      invalid_data = %{
        "a" => %{"b" => "c", "foo" => "bar"}
      }

      assert {:ok, true} == Typedef.validate(schema, valid_data)

      assert {:error, errors} = Typedef.validate(schema, invalid_data)

      assert errors == [
               %Typedef.ErrorPath{
                 instance_path: ["a", "foo"],
                 schema_path: ["properties", "a"]
               }
             ]
    end
  end

  describe "validate/2 — ref form semantics" do
    test "ref delegates validation to referenced definition" do
      schema = %{
        "definitions" => %{
          "a" => %{"type" => "float32"}
        },
        "ref" => "a"
      }

      assert {:ok, true} == Typedef.validate(schema, 123)
    end

    test "ref rejects null and returns errors from referenced schema" do
      schema = %{
        "definitions" => %{
          "a" => %{"type" => "float32"}
        },
        "ref" => "a"
      }

      assert {:error, errors} = Typedef.validate(schema, nil)

      assert errors == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["definitions", "a", "type"]
               }
             ]
    end

    test "nullable true on ref schema allows null instance" do
      schema = %{
        "definitions" => %{
          "a" => %{"type" => "float32"}
        },
        "ref" => "a",
        "nullable" => true
      }

      assert {:ok, true} == Typedef.validate(schema, nil)
    end

    test "nullable false in referenced schema does not override nullable true on ref" do
      schema = %{
        "definitions" => %{
          "a" => %{
            "nullable" => false,
            "type" => "float32"
          }
        },
        "ref" => "a",
        "nullable" => true
      }

      assert {:ok, true} == Typedef.validate(schema, nil)
    end
  end

  describe "validate/2 — type form semantics" do
    test "boolean type accepts booleans and rejects others" do
      schema = %{"type" => "boolean"}

      assert {:ok, true} == Typedef.validate(schema, false)

      assert {:error, errors} = Typedef.validate(schema, 127)

      assert errors == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["type"]
               }
             ]
    end

    test "float32 type accepts numbers and rejects non-numbers" do
      schema = %{"type" => "float32"}

      assert {:ok, true} == Typedef.validate(schema, 10.5)
      assert {:ok, true} == Typedef.validate(schema, 127)

      assert {:error, errors} = Typedef.validate(schema, false)

      assert errors == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["type"]
               }
             ]
    end

    test "string type accepts strings and rejects non-strings" do
      schema = %{"type" => "string"}

      assert {:ok, true} == Typedef.validate(schema, "foo")
      assert {:ok, true} == Typedef.validate(schema, "1985-04-12T23:20:50.52Z")

      assert {:error, errors} = Typedef.validate(schema, false)

      assert errors == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["type"]
               }
             ]
    end

    test "timestamp type accepts RFC3339 strings only" do
      schema = %{"type" => "timestamp"}

      assert {:ok, true} ==
               Typedef.validate(schema, "1985-04-12T23:20:50.52Z")

      assert {:error, errors1} = Typedef.validate(schema, "foo")
      assert {:error, errors2} = Typedef.validate(schema, false)

      assert errors1 == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["type"]
               }
             ]

      assert errors2 == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["type"]
               }
             ]
    end

    test "int8 type accepts integers with zero fractional part in range" do
      schema = %{"type" => "int8"}

      assert {:ok, true} == Typedef.validate(schema, 10)
      assert {:ok, true} == Typedef.validate(schema, 10.0)
      assert {:ok, true} == Typedef.validate(schema, 1.0e1)

      assert {:error, errors1} = Typedef.validate(schema, 10.5)
      assert {:error, errors2} = Typedef.validate(schema, false)

      assert errors1 == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["type"]
               }
             ]

      assert errors2 == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["type"]
               }
             ]
    end

    test "nullable true allows null for type schemas" do
      schema = %{
        "type" => "boolean",
        "nullable" => true
      }

      assert {:ok, true} == Typedef.validate(schema, nil)
      assert {:ok, true} == Typedef.validate(schema, false)

      assert {:error, errors} = Typedef.validate(schema, 127)

      assert errors == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["type"]
               }
             ]
    end
  end

  describe "validate/2 — enum form semantics" do
    test "enum accepts only listed string values" do
      schema = %{
        "enum" => ["PENDING", "DONE", "CANCELED"]
      }

      assert {:ok, true} == Typedef.validate(schema, "PENDING")
      assert {:ok, true} == Typedef.validate(schema, "DONE")
      assert {:ok, true} == Typedef.validate(schema, "CANCELED")

      assert {:error, errors1} = Typedef.validate(schema, 0)
      assert {:error, errors2} = Typedef.validate(schema, "UNKNOWN")
      assert {:error, errors3} = Typedef.validate(schema, nil)

      expected = [
        %ErrorPath{
          instance_path: [],
          schema_path: ["enum"]
        }
      ]

      assert errors1 == expected
      assert errors2 == expected
      assert errors3 == expected
    end

    test "nullable true allows null for enum schemas" do
      schema = %{
        "enum" => ["PENDING", "DONE", "CANCELED"],
        "nullable" => true
      }

      assert {:ok, true} == Typedef.validate(schema, "PENDING")
      assert {:ok, true} == Typedef.validate(schema, nil)

      assert {:error, errors1} = Typedef.validate(schema, 1)
      assert {:error, errors2} = Typedef.validate(schema, "UNKNOWN")

      expected = [
        %ErrorPath{
          instance_path: [],
          schema_path: ["enum"]
        }
      ]

      assert errors1 == expected
      assert errors2 == expected
    end
  end

  describe "validate/2 — elements form semantics" do
    test "elements accepts arrays whose elements all satisfy the subschema" do
      schema = %{
        "elements" => %{
          "type" => "float32"
        }
      }

      assert {:ok, true} == Typedef.validate(schema, [])
      assert {:ok, true} == Typedef.validate(schema, [1, 2, 3])
    end

    test "elements rejects non-array instances" do
      schema = %{
        "elements" => %{
          "type" => "float32"
        }
      }

      assert {:error, errors} = Typedef.validate(schema, nil)

      assert errors == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["elements"]
               }
             ]
    end

    test "elements accumulates errors for invalid array elements" do
      schema = %{
        "elements" => %{
          "type" => "float32"
        }
      }

      instance = [1, 2, "foo", 3, "bar"]

      assert {:error, errors} = Typedef.validate(schema, instance)

      assert errors == [
               %ErrorPath{
                 instance_path: [2],
                 schema_path: ["elements", "type"]
               },
               %ErrorPath{
                 instance_path: [4],
                 schema_path: ["elements", "type"]
               }
             ]
    end

    test "nullable true allows null for elements schemas" do
      schema = %{
        "elements" => %{
          "type" => "float32"
        },
        "nullable" => true
      }

      assert {:ok, true} == Typedef.validate(schema, nil)
      assert {:ok, true} == Typedef.validate(schema, [])
      assert {:ok, true} == Typedef.validate(schema, [1, 2, 3])

      assert {:error, errors} =
               Typedef.validate(schema, [1, 2, "foo", 3, "bar"])

      assert errors == [
               %ErrorPath{
                 instance_path: [2],
                 schema_path: ["elements", "type"]
               },
               %ErrorPath{
                 instance_path: [4],
                 schema_path: ["elements", "type"]
               }
             ]
    end
  end

  describe "validate/2 — properties form semantics" do
    test "accepts objects with required and optional properties" do
      schema = %{
        "properties" => %{
          "a" => %{"type" => "string"},
          "b" => %{"type" => "string"}
        },
        "optionalProperties" => %{
          "c" => %{"type" => "string"},
          "d" => %{"type" => "string"}
        }
      }

      assert {:ok, true} == Typedef.validate(schema, %{"a" => "foo", "b" => "bar"})

      assert {:ok, true} ==
               Typedef.validate(schema, %{"a" => "foo", "b" => "bar", "c" => "baz"})

      assert {:ok, true} ==
               Typedef.validate(schema, %{
                 "a" => "foo",
                 "b" => "bar",
                 "c" => "baz",
                 "d" => "quux"
               })

      assert {:ok, true} ==
               Typedef.validate(schema, %{"a" => "foo", "b" => "bar", "d" => "quux"})
    end

    test "rejects non-object instance" do
      schema = %{
        "properties" => %{
          "a" => %{"type" => "string"}
        }
      }

      assert {:error, errors} = Typedef.validate(schema, nil)

      assert errors == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["properties"]
               }
             ]
    end

    test "rejects missing required properties, invalid values, and additional properties" do
      schema = %{
        "properties" => %{
          "a" => %{"type" => "string"},
          "b" => %{"type" => "string"}
        },
        "optionalProperties" => %{
          "c" => %{"type" => "string"},
          "d" => %{"type" => "string"}
        }
      }

      instance = %{
        "b" => 3,
        "c" => 3,
        "e" => 3
      }

      assert {:error, errors} = Typedef.validate(schema, instance)

      assert errors == [
               %ErrorPath{
                 instance_path: ["a"],
                 schema_path: ["properties", "a"]
               },
               %ErrorPath{
                 instance_path: ["b"],
                 schema_path: ["properties", "b", "type"]
               },
               %ErrorPath{
                 instance_path: ["c"],
                 schema_path: ["optionalProperties", "c", "type"]
               },
               %ErrorPath{
                 instance_path: ["e"],
                 schema_path: []
               }
             ]
    end

    test "additionalProperties true suppresses errors for unknown members" do
      schema = %{
        "properties" => %{
          "a" => %{"type" => "string"},
          "b" => %{"type" => "string"}
        },
        "optionalProperties" => %{
          "c" => %{"type" => "string"},
          "d" => %{"type" => "string"}
        },
        "additionalProperties" => true
      }

      instance = %{
        "b" => 3,
        "c" => 3,
        "e" => 3
      }

      assert {:error, errors} = Typedef.validate(schema, instance)

      assert errors == [
               %ErrorPath{
                 instance_path: ["a"],
                 schema_path: ["properties", "a"]
               },
               %ErrorPath{
                 instance_path: ["b"],
                 schema_path: ["properties", "b", "type"]
               },
               %ErrorPath{
                 instance_path: ["c"],
                 schema_path: ["optionalProperties", "c", "type"]
               }
             ]
    end

    test "nullable true allows null but does not suppress other errors" do
      schema = %{
        "nullable" => true,
        "properties" => %{
          "a" => %{"type" => "string"},
          "b" => %{"type" => "string"}
        },
        "optionalProperties" => %{
          "c" => %{"type" => "string"},
          "d" => %{"type" => "string"}
        },
        "additionalProperties" => true
      }

      assert {:ok, true} == Typedef.validate(schema, nil)

      instance = %{
        "b" => 3,
        "c" => 3,
        "e" => 3
      }

      assert {:error, errors} = Typedef.validate(schema, instance)

      assert errors == [
               %ErrorPath{
                 instance_path: ["a"],
                 schema_path: ["properties", "a"]
               },
               %ErrorPath{
                 instance_path: ["b"],
                 schema_path: ["properties", "b", "type"]
               },
               %ErrorPath{
                 instance_path: ["c"],
                 schema_path: ["optionalProperties", "c", "type"]
               }
             ]
    end
  end

  describe "validate/2 — values form semantics" do
    test "accepts objects whose values all validate against the values schema" do
      schema = %{
        "values" => %{
          "type" => "float32"
        }
      }

      assert {:ok, true} == Typedef.validate(schema, %{})
      assert {:ok, true} == Typedef.validate(schema, %{"a" => 1, "b" => 2})
    end

    test "rejects non-object instances" do
      schema = %{
        "values" => %{
          "type" => "float32"
        }
      }

      assert {:error, errors} = Typedef.validate(schema, nil)

      assert errors == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["values"]
               }
             ]
    end

    test "rejects object members whose values do not validate" do
      schema = %{
        "values" => %{
          "type" => "float32"
        }
      }

      instance = %{
        "a" => 1,
        "b" => 2,
        "c" => "foo",
        "d" => 3,
        "e" => "bar"
      }

      assert {:error, errors} = Typedef.validate(schema, instance)

      assert errors == [
               %ErrorPath{
                 instance_path: ["c"],
                 schema_path: ["values", "type"]
               },
               %ErrorPath{
                 instance_path: ["e"],
                 schema_path: ["values", "type"]
               }
             ]
    end

    test "nullable true allows null but still validates object members" do
      schema = %{
        "nullable" => true,
        "values" => %{
          "type" => "float32"
        }
      }

      assert {:ok, true} == Typedef.validate(schema, nil)

      instance = %{
        "a" => 1,
        "b" => 2,
        "c" => "foo",
        "d" => 3,
        "e" => "bar"
      }

      assert {:error, errors} = Typedef.validate(schema, instance)

      assert errors == [
               %ErrorPath{
                 instance_path: ["c"],
                 schema_path: ["values", "type"]
               },
               %ErrorPath{
                 instance_path: ["e"],
                 schema_path: ["values", "type"]
               }
             ]
    end
  end

  describe "validate/2 — discriminator form semantics" do
    def basic_schema do
      %{
        "discriminator" => "version",
        "mapping" => %{
          "v1" => %{
            "properties" => %{
              "a" => %{"type" => "float32"}
            }
          },
          "v2" => %{
            "properties" => %{
              "a" => %{"type" => "string"}
            }
          }
        }
      }
    end

    test "rejects non-object instance" do
      assert {:error, errors} = Typedef.validate(basic_schema(), nil)

      assert errors == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["discriminator"]
               }
             ]
    end

    test "rejects object missing discriminator tag" do
      assert {:error, errors} = Typedef.validate(basic_schema(), %{})

      assert errors == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["discriminator"]
               }
             ]
    end

    test "rejects discriminator tag with non-string value" do
      assert {:error, errors} =
               Typedef.validate(basic_schema(), %{"version" => 1})

      assert errors == [
               %ErrorPath{
                 instance_path: ["version"],
                 schema_path: ["discriminator"]
               }
             ]
    end

    test "rejects discriminator value not present in mapping" do
      assert {:error, errors} =
               Typedef.validate(basic_schema(), %{"version" => "v3"})

      assert errors == [
               %ErrorPath{
                 instance_path: ["version"],
                 schema_path: ["mapping"]
               }
             ]
    end

    test "rejects instance that does not satisfy selected mapping schema" do
      assert {:error, errors} =
               Typedef.validate(
                 basic_schema(),
                 %{"version" => "v2", "a" => 3}
               )

      assert errors == [
               %ErrorPath{
                 instance_path: ["a"],
                 schema_path: ["mapping", "v2", "properties", "a", "type"]
               }
             ]
    end

    test "accepts valid instance and applies discriminator tag exemption" do
      assert {:ok, true} =
               Typedef.validate(
                 basic_schema(),
                 %{"version" => "v2", "a" => "foo"}
               )
    end

    test "nullable true accepts null" do
      schema =
        basic_schema()
        |> Map.put("nullable", true)

      assert {:ok, true} == Typedef.validate(schema, nil)
    end
  end

  describe "validate/2 — discriminator real-world example" do
    def event_schema do
      %{
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
              "payment_plan" => %{
                "enum" => ["FREE", "PAID"]
              }
            },
            "optionalProperties" => %{
              "upgraded_by" => %{"type" => "string"}
            }
          }
        }
      }
    end

    test "accepts valid discriminator variants" do
      assert {:ok, true} =
               Typedef.validate(
                 event_schema(),
                 %{"event_type" => "account_deleted", "account_id" => "abc-123"}
               )

      assert {:ok, true} =
               Typedef.validate(
                 event_schema(),
                 %{
                   "event_type" => "account_payment_plan_changed",
                   "account_id" => "abc-123",
                   "payment_plan" => "PAID"
                 }
               )

      assert {:ok, true} =
               Typedef.validate(
                 event_schema(),
                 %{
                   "event_type" => "account_payment_plan_changed",
                   "account_id" => "abc-123",
                   "payment_plan" => "PAID",
                   "upgraded_by" => "users/mkhwarizmi"
                 }
               )
    end

    test "rejects missing discriminator tag" do
      assert {:error, errors} =
               Typedef.validate(event_schema(), %{})

      assert errors == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["discriminator"]
               }
             ]
    end

    test "rejects unknown discriminator value" do
      assert {:error, errors} =
               Typedef.validate(
                 event_schema(),
                 %{"event_type" => "some_other_event_type"}
               )

      assert errors == [
               %ErrorPath{
                 instance_path: ["event_type"],
                 schema_path: ["mapping"]
               }
             ]
    end

    test "rejects missing required property in selected mapping" do
      assert {:error, errors} =
               Typedef.validate(
                 event_schema(),
                 %{"event_type" => "account_deleted"}
               )

      assert errors == [
               %ErrorPath{
                 instance_path: [],
                 schema_path: ["mapping", "account_deleted", "properties", "account_id"]
               }
             ]
    end

    test "rejects additional properties when not allowed (except discriminator)" do
      assert {:error, errors} =
               Typedef.validate(
                 event_schema(),
                 %{
                   "event_type" => "account_payment_plan_changed",
                   "account_id" => "abc-123",
                   "payment_plan" => "PAID",
                   "xxx" => "asdf"
                 }
               )

      assert errors == [
               %ErrorPath{
                 instance_path: ["xxx"],
                 schema_path: ["mapping", "account_payment_plan_changed"]
               }
             ]
    end
  end
end
