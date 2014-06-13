#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.Host do
  defstruct [:name, :aliases, :type, :length, :list]

  defp convert({ _, name, aliases, type, length, list }) do
    %Socket.Host{name: name, aliases: aliases, type: type, length: length, list: list}
  end

  @doc """
  Get the hostent by address.
  """
  @spec by_address(Socket.Address.t) :: { :ok, t } | { :error, :inet.posix }
  def by_address(address) do
    case :inet.gethostbyaddr(Socket.Address.parse(address)) do
      { :ok, host } ->
        { :ok, convert(host) }

      error ->
        error
    end
  end

  @doc """
  Get the hostent by address, raising if an error occurs.
  """
  @spec by_address!(Socket.Address.t) :: t | no_return
  def by_address!(address) do
    case :inet.gethostbyaddr(Socket.Address.parse(address)) do
      { :ok, host } ->
        convert(host)

      { :error, code } ->
        raise PosixError, code: code
    end
  end

  @doc """
  Get the hostent by name.
  """
  @spec by_name(binary) :: { :ok, t } | { :error, :inet.posix }
  def by_name(name) when name |> is_binary do
    case :inet.gethostbyname(String.to_char_list(name)) do
      { :ok, host } ->
        { :ok, convert(host) }

      error ->
        error
    end
  end

  @doc """
  Get the hostent by name and family.
  """
  @spec by_name(binary, :inet.address_family) :: { :ok, t } | { :error, :inet.posix }
  def by_name(name, family) when name |> is_binary do
    case :inet.gethostbyname(String.to_char_list(name), family) do
      { :ok, host } ->
        { :ok, convert(host) }

      error ->
        error
    end
  end

  @doc """
  Get the hostent by name, raising if an error occurs.
  """
  @spec by_name!(binary) :: t | no_return
  def by_name!(name) when name |> is_binary do
    case :inet.gethostbyname(String.to_char_list(name)) do
      { :ok, host } ->
        convert(host)

      { :error, code } ->
        raise PosixError, code: code
    end
  end

  @doc """
  Get the hostent by name and family, raising if an error occurs.
  """
  @spec by_name!(binary | char_list, :inet.address_family) :: t | no_return
  def by_name!(name, family) when name |> is_binary do
    case :inet.gethostbyname(String.to_char_list(name), family) do
      { :ok, host } ->
        convert(host)

      { :error, code } ->
        raise PosixError, code: code
    end
  end

  @doc """
  Get the hostname of the machine.
  """
  @spec name :: String.t
  def name do
    case :inet.gethostname do
      { :ok, name } ->
        :unicode.characters_to_list(name)
    end
  end

  @doc """
  Get the interfaces of the machine.
  """
  @spec interfaces :: { :ok, [tuple] } | { :error, :inet.posix }
  def interfaces do
    :inet.getifaddrs
  end

  @doc """
  Get the interfaces of the machine, raising if an error occurs.
  """
  @spec interfaces! :: [tuple] | no_return
  def interfaces! do
    case :inet.getifaddrs do
      { :ok, ifs } ->
        ifs

      { :error, code } ->
        raise PosixError, code: code
    end
  end
end
