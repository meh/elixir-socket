#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.Address do
  require Bitwise

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
    not is_nil(parse(text))
  end

  @doc """
  Convert an ip address tuple to a string.
  """
  @spec to_string(t) :: String.t
  def to_string(address) when address |> is_binary do
    address
  end

  def to_string(address) when address |> is_list do
    address |> IO.iodata_to_binary
  end

  def to_string(address) do
    :inet.ntoa(address) |> IO.iodata_to_binary
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
  
  defp maskv4( addrpart, netsize ) when is_integer(addrpart) and is_integer(netsize) do
	cond do
	  netsize >= 8 -> addrpart
	  netsize >= 1 and netsize < 8 -> 
	    case netsize do
		  1 -> Bitwise.band( addrpart, 0x80 )
		  2 -> Bitwise.band( addrpart, 0xC0 )
		  3 -> Bitwise.band( addrpart, 0xE0 )
		  4 -> Bitwise.band( addrpart, 0xF0 )
		  5 -> Bitwise.band( addrpart, 0xF8 )
		  6 -> Bitwise.band( addrpart, 0xFC )
		  7 -> Bitwise.band( addrpart, 0xFE )
	    end
	  true -> 0
	end
  end
  
  defp maskv6( addrpart, netsize ) when is_integer(addrpart) and is_integer(netsize) do
	cond do
	  netsize >= 16 -> addrpart
	  netsize >= 1 and netsize < 8 -> 
	    case netsize do
		  1 -> Bitwise.band( addrpart, 0x8000 )
		  2 -> Bitwise.band( addrpart, 0xC000 )
		  3 -> Bitwise.band( addrpart, 0xE000 )
		  4 -> Bitwise.band( addrpart, 0xF000 )
		  5 -> Bitwise.band( addrpart, 0xF800 )
		  6 -> Bitwise.band( addrpart, 0xFC00 )
		  7 -> Bitwise.band( addrpart, 0xFE00 )
		  8 -> Bitwise.band( addrpart, 0xFF00 )
		  9 -> Bitwise.band( addrpart, 0xFF80 )
		  10 -> Bitwise.band( addrpart, 0xFFC0 )
		  11 -> Bitwise.band( addrpart, 0xFFE0 )
		  12 -> Bitwise.band( addrpart, 0xFFF0 )
		  13 -> Bitwise.band( addrpart, 0xFFF8 )
		  14 -> Bitwise.band( addrpart, 0xFFFC )
		  15 -> Bitwise.band( addrpart, 0xFFFE )
	    end
	  true -> 0
	end
  end
  
  # for IP V4
  defp is_ip_in_subnet( { net1, net2, net3, net4}, netsize, {addr1, addr2, addr3, addr4} ) do 
    {addr1, addr2, addr3, addr4} = { maskv4(addr1,netsize), maskv4(addr2,netsize-8), maskv4(addr3,netsize-16), maskv4(addr4,netsize-24) }
	{ net1, net2, net3, net4} == { maskv4(net1,netsize), maskv4(net2,netsize-8), maskv4(net3,netsize-16), maskv4(net4,netsize-24) }
	{ net1, net2, net3, net4} == {addr1, addr2, addr3, addr4}
  end

  # for IP V6
  defp is_ip_in_subnet( { net1, net2, net3, net4, net5, net6, net7, net8 }, netsize, {add1, add2, add3, add4, add5, add6, add7, add8} ) do 
    { net1, net2, net3, net4, net5, net6, net7, net8 } = { maskv6(net1,netsize), maskv6(net2,netsize-16), maskv6(net3,netsize-32), maskv6(net4,netsize-48),
														   maskv6(net5,netsize-64), maskv6(net6,netsize-80), maskv6(net7,netsize-96), maskv6(net8,netsize-112) }
    { add1, add2, add3, add4, add5, add6, add7, add8 } = { maskv6(add1,netsize), maskv6(add2,netsize-16), maskv6(add3,netsize-32), maskv6(add4,netsize-48),
														   maskv6(add5,netsize-64), maskv6(add6,netsize-80), maskv6(add7,netsize-96), maskv6(add8,netsize-112) }
	{ net1, net2, net3, net4, net5, net6, net7, net8 } == { add1, add2, add3, add4, add5, add6, add7, add8 }
  end
  
  @doc """
  Check if an IP address belong to a network
  """
  @spec is_in_subnet?(t, t, Integer) :: boolean
  def is_in_subnet?(addr, net, netsize ) when is_integer(netsize) and netsize >= 1 and netsize <= 128 do
    is_ip_in_subnet(net, netsize, addr)
  end
  
end
