#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.Address do
  @type t :: String.t | char_list | :inet.ip_address

  @doc """
  Parse a string to an ip address tuple.
  """
  @spec parse(t) :: :inet.ip_address
  def parse(text) when text |> is_binary do
    parse(String.to_char_list(text))
  end

  def parse(text) when text |> is_list do
    case :inet.parse_address(text) do
      { :ok, ip } ->
        ip

      { :error, :einval } ->
        nil
    end
  end

  def parse(address) do
    address
  end

  @doc """
  Check if the passed string is a valid IP address.
  """
  @spec valid?(t) :: boolean
  def valid?(text) do
    not nil?(parse(text))
  end

  @doc """
  Convert an ip address tuple to a string.
  """
  @spec to_string(t) :: String.t
  def to_string(address) when address |> is_binary do
    address
  end

  def to_string(address) when address |> is_list do
    address |> iodata_to_binary
  end

  def to_string(address) do
    :inet.ntoa(address) |> iodata_to_binary
  end

  @doc """
  Get the addresses for the given host.
  """
  @spec for(t, :inet.address_family) :: { :ok, [t] } | { :error, :inet.posix }
  def for(host, family) do
    :inet.getaddrs(parse(host), family)
  end

  @doc """
  Get the addresses for the given host, raising if an error occurs.
  """
  @spec for!(t, :inet.address_family) :: [t] | no_return
  def for!(host, family) do
    case :inet.getaddrs(parse(host), family) do
      { :ok, addresses } ->
        addresses

      { :error, code } ->
        raise PosixError, code: code
    end
  end
end
