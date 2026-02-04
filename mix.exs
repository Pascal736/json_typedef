defmodule Typedef.MixProject do
  use Mix.Project

  def project do
    [
      app: :typedef,
      description: "Implementation of rfc8927 to validate JSON typedef structures.",
      version: "0.0.1",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: [
        {:ex_doc, "~> 0.31", only: :dev, runtime: false}
      ],
      package: package()
    ]
  end

  def application do
    []
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Pascal Pfeiffer"],
      links: %{
        "GitHub" => "https://github.com/pascal736/json_typedef"
      }
    ]
  end
end
