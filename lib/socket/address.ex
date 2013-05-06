defmodule Socket.Address do
  def parse(text) when is_binary text do
    parse(binary_to_list(text))
  end

  def parse(text) do
    case :inet.parse_address(text) do
      { :ok, ip } ->
        ip

      { :error, :einval } ->
        nil
    end
  end
end
