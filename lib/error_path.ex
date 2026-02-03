defmodule JsonTypedef.ErrorPath do
  @enforce_keys [:instance_path, :schema_path]
  defstruct instance_path: [], schema_path: []
end
