# frozen_string_literal: true
#
# Copyright 2024-2026 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require_relative "aut_aut"
AutAut.setup exclude: '^exe'

module Nuttall
  VERSION = "0.6.50"
  APP_DIR = File.expand_path(__dir__)

  Extensions.apply
end
