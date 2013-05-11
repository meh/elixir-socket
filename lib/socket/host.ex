#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defrecord Socket.Host, [:name, :aliases, :type, :length, :list] do
  def for(host, family) do
    :inet.getaddrs(Socket.Address.parse(host), family)
  end

  def for!(host, family) do
    case :inet.getaddrs(Socket.Address.parse(host), family) do
      { :ok, addresses } ->
        addresses

      { :error, code } ->
        raise PosixError, code: code
    end
  end

  def by_address(address) do
    case :inet.gethostbyaddr(Socket.Address.parse(address)) do
      { :ok, host } ->
        { :ok, set_elem host, 0, Socket.Host }

      error ->
        error
    end
  end

  def by_address!(address) do
    case :inet.gethostbyaddr(Socket.Address.parse(address)) do
      { :ok, host } ->
        set_elem host, 0, Socket.Host

      { :error, code } ->
        raise PosixError, code: code
    end
  end

  def by_name(name) do
    if is_binary(name) do
      name = binary_to_list(name)
    end

    case :inet.gethostbyname(name) do
      { :ok, host } ->
        { :ok, set_elem host, 0, Socket.Host }

      error ->
        error
    end
  end

  def by_name(name, family) do
    if is_binary(name) do
      name = binary_to_list(name)
    end

    case :inet.gethostbyname(name, family) do
      { :ok, host } ->
        { :ok, set_elem host, 0, Socket.Host }

      error ->
        error
    end
  end

  def by_name!(name) do
    if is_binary(name) do
      name = binary_to_list(name)
    end

    case :inet.gethostbyname(name) do
      { :ok, host } ->
        set_elem host, 0, Socket.Host

      { :error, code } ->
        raise PosixError, code: code
    end
  end

  def by_name!(name, family) do
    if is_binary(name) do
      name = binary_to_list(name)
    end

    case :inet.gethostbyname(name, family) do
      { :ok, host } ->
        set_elem host, 0, Socket.Host

      { :error, code } ->
        raise PosixError, code: code
    end
  end

  def name do
    case :inet.gethostname do
      { :ok, name } ->
        :unicode.characters_to_list(name)
    end
  end

  def interfaces do
    :inet.getifaddrs
  end

  def interfaces! do
    case :inet.getifaddrs do
      { :ok, ifs } ->
        ifs

      { :error, code } ->
        raise PosixError, code: code
    end
  end
end
