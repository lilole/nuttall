# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  class Cli
    def self.usage(message="Online help.", exit_code=1)
      prog = "nuttall"
      $stderr << <<~END

        Message:
          #{message}

        Name:
          #{prog} v#{Nuttall::Version}

        Description:
          Main management tool for Nuttall logging systems.

        Usage:
          #{prog} create
          #{prog} start
          #{prog} status
          #{prog} stop

        Where:
          create => Create a new service on the current machine.

          start => Start service(s) on the current machine.

          status => Check status of service(s) on the current machine.

          stop => Stop service(s) on the current machine.

      END
      exit(exit_code) if exit_code && exit_code >= 0
    end

    attr_reader :args

    def initialize(args)
      @args = args
      @config = Config.new
    end

    def run
      parse_args
      true
    rescue => e
      $stderr << e.full_message
      false
    end

    def parse_args
      Cli.usage
    end
  end
end
