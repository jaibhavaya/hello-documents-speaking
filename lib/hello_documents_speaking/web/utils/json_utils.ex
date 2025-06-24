defmodule HelloDocumentsSpeaking.Web.Utils.JsonUtils do
  @moduledoc """
  JSON utility that ensures API responses always use camelCase keys like the Rails API.
  """

  @doc """
  Encodes data to JSON with camelCase keys.
  Use this instead of Jason.encode! to ensure consistent camelCase output.
  """
  def encode!(data) do
    data
    |> to_camel_case()
    |> Jason.encode!()
  end

  @doc """
  Decodes JSON and converts camelCase keys to snake_case.
  Use this to handle incoming camelCase data from frontend.
  """
  def decode!(json) do
    json
    |> Jason.decode!()
    |> to_snake_case()
  end

  @doc """
  Converts snake_case keys to camelCase recursively.
  """
  def to_camel_case(data) when is_map(data) do
    data
    |> Enum.map(fn {key, value} -> {snake_to_camel(key), to_camel_case(value)} end)
    |> Enum.into(%{})
  end

  def to_camel_case(data) when is_list(data) do
    Enum.map(data, &to_camel_case/1)
  end

  def to_camel_case(data), do: data

  @doc """
  Converts camelCase keys to snake_case recursively.
  """
  def to_snake_case(data) when is_map(data) do
    data
    |> Enum.map(fn {key, value} -> {camel_to_snake(key), to_snake_case(value)} end)
    |> Enum.into(%{})
  end

  def to_snake_case(data) when is_list(data) do
    Enum.map(data, &to_snake_case/1)
  end

  def to_snake_case(data), do: data

  defp snake_to_camel(key) when is_atom(key) do
    key |> Atom.to_string() |> snake_to_camel()
  end

  defp snake_to_camel(key) when is_binary(key) do
    case String.split(key, "_") do
      [first | rest] ->
        first <> Enum.map_join(rest, "", &String.capitalize/1)

      _ ->
        key
    end
  end

  defp snake_to_camel(key), do: key

  defp camel_to_snake(key) when is_atom(key) do
    key |> Atom.to_string() |> camel_to_snake()
  end

  defp camel_to_snake(key) when is_binary(key) do
    key
    |> String.replace(~r/([A-Z])/, "_\\1")
    |> String.downcase()
    |> String.trim_leading("_")
  end

  defp camel_to_snake(key), do: key
end

