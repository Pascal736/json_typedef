defmodule Typedef.ErrorPath do
  @enforce_keys [:instance_path, :schema_path]
  defstruct instance_path: [], schema_path: []

  @type t :: %__MODULE__{
          instance_path: [String.t() | integer()],
          schema_path: [String.t()]
        }
end
