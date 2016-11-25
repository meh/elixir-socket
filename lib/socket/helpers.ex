defmodule Socket.Helpers do
  defmacro __using__(_opts) do
    quote do
      import Socket.Helpers
    end
  end

  defmacro defbang({ name, _, args }) do
    args = if is_list(args), do: args, else: []

    quote bind_quoted: [name: Macro.escape(name), args: Macro.escape(args)] do
      def unquote(to_string(name) <> "!" |> String.to_atom)(unquote_splicing(args)) do
        case unquote(name)(unquote_splicing(args)) do
          :ok ->
            :ok

          { :ok, result } ->
            result

          { :error, reason } ->
            raise Socket.Error, reason: reason
        end
      end
    end
  end

  defmacro defbang({ name, _, args }, to: mod) do
    args = if is_list(args), do: args, else: []

    quote bind_quoted: [mod: Macro.escape(mod), name: Macro.escape(name), args: Macro.escape(args)] do
      def unquote(to_string(name) <> "!" |> String.to_atom)(unquote_splicing(args)) do
        case unquote(mod).unquote(name)(unquote_splicing(args)) do
          :ok ->
            :ok

          { :ok, result } ->
            result

          { :error, reason } ->
            raise Socket.Error, reason: reason
        end
      end
    end
  end

  defmacro defwrap({ name, _, [self | args] }, options \\ []) do
    if instance = options[:to] do
      quote bind_quoted: [name: Macro.escape(name), self: Macro.escape(self), args: Macro.escape(args), instance: Macro.escape(instance), field: options[:field] || :socket] do
        def unquote(name)(unquote(self), unquote_splicing(args)) do
          unquote(self).unquote(field) |> @protocol.unquote(instance).unquote(name)(unquote_splicing(args))
        end
      end
    else
      quote bind_quoted: [name: Macro.escape(name), self: Macro.escape(self), args: Macro.escape(args), field: options[:field] || :socket] do
        def unquote(name)(unquote(self), unquote_splicing(args)) do
          unquote(self).unquote(field) |> @protocol.unquote(name)(unquote_splicing(args))
        end
      end
    end
  end

  defmacro definvalid({ name, _, args }) do
    args = if args |> is_list do
      for { _, meta, context } <- args do
        { :_, meta, context }
      end
    else
      []
    end

    quote do
      def unquote(name)(unquote_splicing(args)) do
        { :error, :einval }
      end
    end
  end
end
