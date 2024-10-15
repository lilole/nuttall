# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  class Cli
    attr_reader :args

    def initialize(args)
      @args = args
    end

    def run
      parse_args
      true
    rescue => e
      $stderr << e.full_message
      false
    end

    def parse_args
      nil
    end
  end
end
