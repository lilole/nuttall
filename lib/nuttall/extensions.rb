# frozen_string_literal: true
#
# Copyright 2024-2025 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  module Extensions
    def self.apply
      # Order matters. Deeper (more base level) exts should apply first.
      Object.apply
      Numeric.apply
    end
  end
end
