# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
module Op
  class Create
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def run
      raise NotImplementedError
    end
  end
end
end
