# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  APP_DIR = File.expand_path("..", __dir__)

  VERSION = File.read("#{APP_DIR}/VERSION").strip

  Extensions.apply
end
