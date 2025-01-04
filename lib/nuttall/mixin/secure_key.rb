# frozen_string_literal: true
#
# Copyright 2024-2025 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "base64"
require "securerandom"

module Nuttall
module Mixin
  module SecureKey
    SecureKey = self

    def self.generate_typable(bits: 512, force: false)
      assert_valid_bits(bits) if ! force
      bin_key = generate_binary(bits: bits, force: true)
      key = Base64.urlsafe_encode64(bin_key, padding: false)
      expect_sz = best_typable_length(bits)
      raise "Invalid generated length: Expected #{expect_sz}, got #{key.size}" if key.size != expect_sz
      key
    end

    def self.assert_valid_bits(bits)
      bits.is_a?(Integer) or raise ArgumentError, "Bits must be Integer: #{bits.ellipsify}"
      bits > 0            or raise ArgumentError, "Bits must be positive: #{bits}"
      bits % 8 == 0       or raise ArgumentError, "Bits must be multiple of 8: #{bits}"
    end

    def self.best_typable_length(bits)
      bits / 6 + (bits % 6 == 0 ? 0 : 1)
    end

    def self.generate_binary(bits: 512, force: false)
      assert_valid_bits(bits) if ! force
      SecureRandom.bytes(bits / 8)
    end
  end
end
end
