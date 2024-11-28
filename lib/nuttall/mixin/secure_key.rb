# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "base64"
require "securerandom"

module Nuttall
module Mixin
  module SecureKey
    SecureKey = self

    def self.generate_typable(bits: 512)
      raise "Bits must be multiple of 8" if bits % 8 != 0
      key = SecureRandom.bytes(bits / 8)
      Base64.urlsafe_encode64(key, padding: false)
    end
  end
end
end
