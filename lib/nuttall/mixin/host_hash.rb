# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "base64"
require "digest/md5"
require "socket"

module Nuttall
module Mixin
  module HostHash
    ### Return a base64-encoded unique hash key for the current host.
      # The largest possible hash value is 22 URL-safe characters, to hold 128
      # bits. However the default is to trim the hash down to 10 chars, which
      # makes the default case 60 bits deep. This should be a good tradeoff
      # between collision avoidance and usage convenience.
      #
      # Pass `with_time` false to return the same value every time, but still
      # unique in the local network. Default is a unique value every time for
      # both host and local network.
      #
    def host_hash(with_time: true, compact: 10)
      digester = Digest::MD5.new
      digester << Time.now.to_f.to_s if with_time

      addrs = Socket.ip_address_list
      subset = addrs.select(&:ipv6?)
      subset = addrs.select(&:ipv4?) if subset.none?

      ips = subset.any? ? subset.map(&:ip_address) : ["::1"]

      ips.sort.each { |ip| digester << ip }

      hash = Base64.urlsafe_encode64(digester.digest, padding: false)
      hash2 = hash.gsub(/[-_]+/, "")
      hash = hash2 if hash2.size >= compact
      hash[0, compact]
    end
  end
end
end
