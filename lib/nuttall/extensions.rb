# frozen_string_literal: true
#
# Copyright 2024-2025 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  module Extensions
    def self.apply
      require_relative "extensions/object" # BUG: AutAut should handle this
      ::Nuttall::Extensions::Object.apply
      ::Ulse::Ext::Numeric::Commafy.apply
      ::Ulse::Ext::String::Ellipt.apply
    end
  end
end
