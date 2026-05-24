# frozen_string_literal: true
#
# Copyright 2024-2025 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  module Extensions
    # Order matters. Deeper (more base level) exts should apply first.
    ALL = %i[Object Numeric]

    def self.apply
      ALL.each { |name|
        ::Object.const_get("#{self.name}::#{name}").apply
      }
    end
  end
end
