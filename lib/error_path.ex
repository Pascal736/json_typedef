defmodule JsonTypedef.ErrorPath do
  @enforce_keys [:instance_path, :schema_path]
  # TODO: Think about list or string.
  defstruct instance_path: "", schema_path: ""
end
