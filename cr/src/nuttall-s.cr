# The logging service to run inside the Nuttall container.
#
# Copyright 2024-2025 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "./server/core"

module Nuttall
module Server
  class Cli
    getter :args, :config

    def initialize(args : Array(String))
      @args = args
      @config = uninitialized Hash(Symbol, String)
    end

    def run
      parse_args
      Nuttall::Server::Core.new(config).run
      0
    rescue e
      e.inspect_with_backtrace(STDERR)
      1
    end

    def parse_args
      @config = {} of Symbol => String
    end
  end
end
end

exit(Nuttall::Server::Cli.new(ARGV).run)
