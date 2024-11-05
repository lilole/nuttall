# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  VERSION = File.read(File.expand_path("../VERSION", __dir__)).strip

  Extensions.apply
end
