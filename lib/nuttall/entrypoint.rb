# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  class Entrypoint
    include Container::Startup

    def usage(msg="Internal only.", exit_code=1)
      $stderr << <<~END

        #{msg}

        This tool is internal, not for general use. Do not call it.

      END
      exit(exit_code) if exit_code
    end

    attr_reader :args

    def initialize(args)
      @args = args
    end

    def run
      parse_args
      bootstrap
      start_workers
      start_monitors
      true
    rescue => e
      $stderr << e.full_message
      false
    end

    def parse_args
      usage if args.any?
    end
  end
end
