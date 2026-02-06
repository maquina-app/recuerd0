require "ipaddr"

module Analytics
  module IpAnonymizer
    module_function

    def anonymize(ip_string)
      return nil if ip_string.blank?

      addr = IPAddr.new(ip_string)

      if addr.ipv4?
        addr.mask(24).to_s
      else
        addr.mask(48).to_s
      end
    rescue IPAddr::InvalidAddressError
      ip_string
    end
  end
end
