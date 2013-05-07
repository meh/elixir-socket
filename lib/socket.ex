defmodule Socket do
  defexception Error, code: nil do
    def message(self) do
      to_binary(:inet.format_error(self.code))
    end
  end

  def arguments(options) do
    args = []

    if Keyword.has_key?(options, :route) do
      args = [{ :dontroute, !options[:route] } | args]
    end

    if options[:priority] do
      args = [{ :priority, options[:priority] } | args]
    end

    if options[:tos] do
      args = [{ :tos, options[:tos] } | args]
    end

    if send = options[:send] do
      case send[:timeout] do
        { timeout, :close } ->
          args = [{ :send_timeout, timeout }, { :send_timeout_close, true } | args]

        timeout when is_integer(timeout) ->
          args = [{ :send_timeout, timeout } | args]
      end

      if send[:delay] do
        args = [{ :delay_send, send[:delay] } | args]
      end

      if send[:buffer] do
        args = [{ :sndbuf, send[:buffer] } | args]
      end
    end

    if recv = options[:recv] do
      if recv[:buffer] do
        args = [{ :recbuf, recv[:buffer] } | args]
      end
    end

    args
  end
end
