# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
module Container
  class Builder
    attr_reader :config, :settings

    def initialize(config)
      @config = config
      @settings = config.user_file_settings
    end

    def run
      raise NotImplementedError
    end
  end
end
end
