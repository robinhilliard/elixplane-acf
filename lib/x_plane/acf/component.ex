defmodule XPlane.Acf.Component do
  @moduledoc false

  # Shared implementation for the indexed, array-backed semantic components
  # (wings, engines, props, gear, ...). `use`-ing this defines the struct (from
  # the `XPlane.Acf.Schema` field list plus `:index` and any `:extra` fields),
  # plus `from_doc/2` and `all/1`. Components can override `augment/3` to derive
  # additional fields (see `XPlane.Acf.Wing`).

  defmacro __using__(opts) do
    quote bind_quoted: [
            kind: Keyword.fetch!(opts, :kind),
            prefix: Keyword.fetch!(opts, :prefix),
            extra: Keyword.get(opts, :extra, [])
          ] do
      @kind kind
      @prefix prefix
      @schema_fields XPlane.Acf.Schema.fields(kind) |> Enum.map(&elem(&1, 0))

      defstruct [:index | @schema_fields] ++ extra
      @type t :: %__MODULE__{}

      @doc false
      def __kind__, do: @kind

      @doc false
      def __prefix__, do: @prefix

      @doc "Build one component from `doc` at `index`."
      @spec from_doc(XPlane.Acf.Document.t(), non_neg_integer()) :: t()
      def from_doc(doc, index) do
        base = doc |> XPlane.Acf.Schema.read(@kind, index) |> Map.put(:index, index)
        struct(__MODULE__, augment(doc, index, base))
      end

      @doc "All populated components of this kind in `doc`, by ascending index."
      @spec all(XPlane.Acf.Document.t()) :: [t()]
      def all(doc) do
        doc |> XPlane.Acf.Array.indices(@prefix) |> Enum.map(&from_doc(doc, &1))
      end

      defp augment(_doc, _index, base), do: base
      defoverridable augment: 3
    end
  end
end
