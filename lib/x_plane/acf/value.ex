defmodule XPlane.Acf.Value do
  @moduledoc """
  Coercion and formatting helpers for X-Plane `.acf` property values.

  Property values are stored verbatim as strings so that an unmodified
  document round-trips byte-for-byte. These helpers convert to typed Elixir
  values on demand (when reading) and back to strings (when a property is
  changed). Changed values are only required to be *valid*, not byte-identical
  to what Plane-Maker would emit.
  """

  @doc """
  Parse a raw value as a float. Accepts integer-looking strings (`"8"` -> `8.0`).
  """
  @spec to_float(String.t()) :: float()
  def to_float(raw) when is_binary(raw) do
    case Float.parse(String.trim(raw)) do
      {f, _rest} -> f
      :error -> 0.0
    end
  end

  @doc """
  Parse a raw value as an integer. Truncates trailing fractional text
  (`"1100.0"` -> `1100`).
  """
  @spec to_integer(String.t()) :: integer()
  def to_integer(raw) when is_binary(raw) do
    case Integer.parse(String.trim(raw)) do
      {i, _rest} -> i
      :error -> 0
    end
  end

  @doc """
  Parse a raw value as a boolean. X-Plane uses `1`/`0`.
  """
  @spec to_boolean(String.t()) :: boolean()
  def to_boolean(raw) when is_binary(raw) do
    String.trim(raw) in ["1", "true", "TRUE"]
  end

  @doc """
  Format an Elixir value as the string stored in the `.acf` file.
  """
  @spec format(number() | boolean() | String.t()) :: String.t()
  def format(value) when is_integer(value), do: Integer.to_string(value)
  def format(value) when is_float(value), do: Float.to_string(value)
  def format(true), do: "1"
  def format(false), do: "0"
  def format(value) when is_binary(value), do: value
end
