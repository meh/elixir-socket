#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

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
