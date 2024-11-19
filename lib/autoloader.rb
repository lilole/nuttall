# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "zeitwerk"

Zeitwerk::Loader.new.tap do |loader|
  project_dir = File.expand_path("..", __dir__)
  loader.push_dir("#{project_dir}/lib")
  loader.setup
end
