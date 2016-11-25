defmodule AddressTest do
  use ExUnit.Case

  alias Socket.Address, as: Addr

  test "Parse string to ip tuple" do
    assert Addr.parse("127.0.0.1") == {127,0,0,1}
    assert Addr.parse("0.0.0.0") == {0,0,0,0}
    assert Addr.parse("0.0.0.111111") == nil
    assert Addr.parse("255.255.255.255") == {255, 255, 255, 255}
    assert Addr.parse("255.255.255.256") == nil
    assert Addr.parse("*") == nil
    assert Addr.parse("::") == {0, 0, 0, 0, 0, 0, 0, 0}
    assert Addr.parse("1.1.1") == nil
    assert Addr.parse("222221.1.1") == nil
    assert Addr.parse("localhost") == nil
  end

  test "Check if the string is a valid ip" do
    assert Addr.valid?("127.0.0.1") == true
    assert Addr.valid?("localhost") == false
    assert Addr.valid?("1.1.1.1.1.1.1") == false
    assert Addr.valid?("1.1.1.1") == true
    assert Addr.valid?("0.0.0.0") == true
    assert Addr.valid?("0.0.0") == false
    assert Addr.valid?("256.0.0.1") == false
  end

  test "Convert ip tuple to string" do
    assert Addr.to_string({127,0,0,1}) == "127.0.0.1"
    assert Addr.to_string({255,0,0,1}) == "255.0.0.1"
  end

  test "Get ip address for host" do
    {ret, _addresses} = Addr.for("localhost", :inet)
    assert ret == :ok
    {ret, _addresses} = Addr.for("baidu.com", :inet)
    assert ret == :ok
  end
end

