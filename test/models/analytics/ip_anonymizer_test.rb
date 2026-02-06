require "test_helper"

class Analytics::IpAnonymizerTest < ActiveSupport::TestCase
  test "zeroes last octet of IPv4 address" do
    assert_equal "192.168.1.0", Analytics::IpAnonymizer.anonymize("192.168.1.42")
    assert_equal "10.0.0.0", Analytics::IpAnonymizer.anonymize("10.0.0.255")
    assert_equal "172.16.0.0", Analytics::IpAnonymizer.anonymize("172.16.0.1")
  end

  test "zeroes last 80 bits of IPv6 address" do
    result = Analytics::IpAnonymizer.anonymize("2001:db8:85a3:1234:5678:8a2e:0370:7334")
    assert_equal "2001:db8:85a3::", result

    result = Analytics::IpAnonymizer.anonymize("::1")
    assert_equal "::", result
  end

  test "returns nil for nil or blank input" do
    assert_nil Analytics::IpAnonymizer.anonymize(nil)
    assert_nil Analytics::IpAnonymizer.anonymize("")
    assert_nil Analytics::IpAnonymizer.anonymize("   ")
  end

  test "returns input unchanged for unparseable addresses" do
    assert_equal "not-an-ip", Analytics::IpAnonymizer.anonymize("not-an-ip")
    assert_equal "abc.def.ghi.jkl", Analytics::IpAnonymizer.anonymize("abc.def.ghi.jkl")
  end
end
